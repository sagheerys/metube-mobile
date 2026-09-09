import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/home/download_watcher.dart';
import 'package:metube_super/features/home/notifications.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/settings/status_refresh.dart';
import 'package:metube_super/features/settings/widgets/server_status_card.dart';
import 'package:metube_super/features/shared/error_report.dart';
import 'package:mt_core/mt_core.dart';

/// **Error-review guards** (requested 2026-09-06).
///
/// The diagnostic log was a download log rather than an error log: forty
/// places show an error message and not one of them reached the log, not
/// even the library collapsing with a 401 (2026-09-05). And Super had no
/// download notifications at all.
void main() {
  late MTLogger logger;
  late File logFile;

  setUp(() async {
    logFile = File(
      '${Directory.systemTemp.path}/mtf_err_${DateTime.now().microsecondsSinceEpoch}.log',
    );
    logger = MTLogger(filePath: logFile.path);
    clearErrorSignature('history');
    clearErrorSignature('probe');
  });

  tearDown(() async {
    if (await logFile.exists()) await logFile.delete();
  });

  /// The write is deliberately not awaited, so the interface is not slowed
  /// for the log's sake, which makes the wait here a short poll rather than
  /// a fixed timeout that varies with disk speed.
  Future<String> waitForLog(String needle) async {
    for (var i = 0; i < 40; i++) {
      final text = await logger.readAll();
      if (text.contains(needle)) return text;
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    return logger.readAll();
  }

  group('مرشّح التكرار', () {
    test('نفس الخطأ من نفس المصدر يُسجَّل مرة واحدة', () async {
      logErrorOnce(logger, 'probe', const NetworkException('down'));
      logErrorOnce(logger, 'probe', const NetworkException('down'));
      logErrorOnce(logger, 'probe', const NetworkException('down'));
      final text = await waitForLog('probe');
      // The guard: live polling every two seconds would fill the
      // thousand-line ring log with one fault in half an hour, erasing the
      // app's whole history.
      expect('probe:'.allMatches(text).length, 1);
    });

    test('خطأ مختلف من نفس المصدر يُسجَّل', () async {
      logErrorOnce(logger, 'probe', const NetworkException('down'));
      logErrorOnce(logger, 'probe', const AuthFailureException('HTTP 401'));
      final text = await waitForLog('401');
      expect('probe:'.allMatches(text).length, 2);
    });

    test('بعد التعافي يُسجَّل تكرار العطل — حدث جديد', () async {
      logErrorOnce(logger, 'probe', const NetworkException('down'));
      clearErrorSignature('probe');
      logErrorOnce(logger, 'probe', const NetworkException('down'));
      final text = await waitForLog('probe');
      expect('probe:'.allMatches(text).length, 2);
    });
  });

  group('فشل المكتبة يصل السجل', () {
    ProviderContainer containerWith(int status) {
      final dio = Dio()..httpClientAdapter = _StatusAdapter(status);
      return ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
          prefsMutexProvider.overrideWithValue(PrefsMutex()),
          initialSettingsProvider.overrideWithValue(
            const SuperSettings(activeUrl: 'https://srv.example.com'),
          ),
          loggerProvider.overrideWithValue(logger),
          apiClientProvider.overrideWithValue(
            MeTubeApiClient(
              config: ServerConfig(baseUrl: 'https://srv.example.com'),
              dio: dio,
            ),
          ),
        ],
      );
    }

    test('رفض الاعتماد (401) يُكتب في السجل بوسم الشبكة', () async {
      final container = containerWith(401);
      addTearDown(container.dispose);
      await expectLater(
        container.read(historyProvider.future),
        throwsA(isA<AuthFailureException>()),
      );
      // **The guard**: this is exactly what happened in the field and left
      // no trace.
      expect(await waitForLog('history'), contains('AuthFailureException'));
    });

    test('نجاح السجل لا يكتب شيئاً', () async {
      final container = containerWith(200);
      addTearDown(container.dispose);
      await container.read(historyProvider.future);
      await Future<void>.delayed(const Duration(milliseconds: 60));
      expect(await logger.readAll(), isNot(contains('history')));
    });
  });

  group('بطاقة الحالة لا تكذب بعد العودة', () {
    testWidgets('العودة إلى التطبيق تعيد سؤال السيرفر', (tester) async {
      var probes = 0;
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
          prefsMutexProvider.overrideWithValue(PrefsMutex()),
          initialSettingsProvider.overrideWithValue(const SuperSettings()),
          loggerProvider.overrideWithValue(logger),
          serverStatusProvider.overrideWith((ref) async {
            probes++;
            return MTEndpointStatus.ok;
          }),
        ],
      );
      addTearDown(container.dispose);
      // A listener keeps the provider alive; invalidating does not
      // recompute a provider nobody watches.
      container.listen(serverStatusProvider, (_, _) {});
      container.read(statusRefreshProvider);
      await tester.pump();
      expect(probes, 1);

      // The full sequence the framework requires (skipping is rejected by
      // an assertion): leaving is resumed, inactive, hidden, paused, and
      // returning is the reverse.
      for (final state in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));
      // **The guard**: without this the provider stays cached with no
      // `autoDispose` and no timer, so the card says "connected" hours
      // after the server went down, until the user presses refresh (review
      // 2026-09-06).
      expect(probes, 2);
    });
  });

  group('إشعارات Super (قرار المالك 2026-09-06)', () {
    test('مهمة فاشلة ⇒ إشعار خطأ يحمل سبب الفشل لا كلمة «فشل»', () async {
      final fake = _FakeNotifications();
      final tasks = StreamController<List<DownloadTask>>();
      addTearDown(tasks.close);
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
          prefsMutexProvider.overrideWithValue(PrefsMutex()),
          initialSettingsProvider.overrideWithValue(
            const SuperSettings(localeCode: 'ar'),
          ),
          loggerProvider.overrideWithValue(logger),
          notificationsProvider.overrideWithValue(fake),
          engineTasksProvider.overrideWith((ref) => tasks.stream),
        ],
      );
      addTearDown(container.dispose);
      container.read(downloadWatcherProvider);

      tasks.add([
        DownloadTask(
          id: 't1',
          inputUrl: 'https://youtu.be/x',
          quality: Quality.best,
          phase: TaskPhase.failed,
          error: const AuthFailureException('HTTP 401'),
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(fake.results, hasLength(1));
      expect(fake.results.single.isError, isTrue);
      // The guard: "failed" alone leaves the user guessing between the
      // network, the link and the credentials.
      expect(fake.results.single.body, isNot('فشل'));
      expect(fake.results.single.body, contains('كلمة المرور'));
    });

    test('مهمة مكتملة ⇒ إشعار نتيجة بحمولة تُبرز العنصر', () async {
      final fake = _FakeNotifications();
      final tasks = StreamController<List<DownloadTask>>();
      addTearDown(tasks.close);
      final container = ProviderContainer(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
          prefsMutexProvider.overrideWithValue(PrefsMutex()),
          initialSettingsProvider.overrideWithValue(
            const SuperSettings(localeCode: 'ar'),
          ),
          loggerProvider.overrideWithValue(logger),
          notificationsProvider.overrideWithValue(fake),
          engineTasksProvider.overrideWith((ref) => tasks.stream),
        ],
      );
      addTearDown(container.dispose);
      container.read(downloadWatcherProvider);

      tasks.add([
        DownloadTask(
          id: 't2',
          inputUrl: 'https://youtu.be/y',
          quality: Quality.best,
          phase: TaskPhase.completed,
          canonicalUrl: 'https://youtu.be/y',
          title: 'مقطع',
        ),
      ]);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(fake.results.single.isError, isFalse);
      expect(fake.results.single.payload, 'https://youtu.be/y');
    });
  });
}

class _Result {
  _Result(this.body, this.isError, this.payload);
  final String body;
  final bool isError;
  final String? payload;
}

class _FakeNotifications extends DownloadNotifications {
  final results = <_Result>[];
  final progress = <String>[];

  @override
  Future<void> init({void Function(String itemKey)? onOpenItem}) async {}

  @override
  Future<void> requestPermission() async {}

  @override
  Future<void> showProgress(
    int id, {
    required String title,
    required String channelName,
    required int? percent,
    String? body,
  }) async {
    progress.add('$title|$body|$percent');
  }

  @override
  Future<void> showResult(
    int id, {
    required String title,
    required String body,
    required String channelName,
    String? payload,
    bool isError = false,
  }) async {
    results.add(_Result(body, isError, payload));
  }

  @override
  Future<void> cancel(int id) async {}
}

/// An adapter returning one HTTP status, with no network.
class _StatusAdapter implements HttpClientAdapter {
  _StatusAdapter(this.status);

  final int status;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody.fromBytes(
      utf8.encode(status == 200 ? '{"done":[],"queue":[]}' : 'denied'),
      status,
      headers: {
        't': [status == 200 ? 'application/json' : 'text/plain'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
