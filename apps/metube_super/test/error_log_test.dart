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

/// **حرّاس فحص الأخطاء (طلب المالك 2026-09-06).**
///
/// كان السجل التشخيصي سجلَّ تحميلات لا سجلَّ أخطاء: أربعون موضع رسالة
/// خطأ ولا واحد منها يصل السجل — حتى انهيار المكتبة بـ401 (2026-09-05)
/// مرّ بلا سطر. وكان Super بلا إشعارات تحميل إطلاقاً.
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

  /// الكتابة غير منتظَرة بقصد (لا نُبطئ الواجهة لأجل السجل) — فالانتظار
  /// هنا استطلاعٌ قصير بدل مهلة ثابتة تتقلب مع سرعة القرص.
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
      // الحارس: الاستطلاع الحي كل ثانيتين كان سيملأ السجل الحلقي
      // (1000 سطر) بعطلٍ واحد في نصف ساعة، فيمحو تاريخ التطبيق كله.
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
      // **الحارس**: هذا بالضبط ما جرى للمالك ولم يترك أثراً.
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
      // مستمع يبقي المزوّد حياً — الإبطال لا يعيد حساب مزوّد لا يُراقَب.
      container.listen(serverStatusProvider, (_, _) {});
      container.read(statusRefreshProvider);
      await tester.pump();
      expect(probes, 1);

      // التسلسل الكامل الذي يفرضه إطار العمل (القفز يرفضه بتأكيد):
      // خروجاً resumed→inactive→hidden→paused، وعودةً بالعكس.
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
      // **الحارس**: بلا هذا يبقى المزوّد محفوظاً بلا `autoDispose` ولا
      // مؤقّت، فتقول البطاقة «متصل» وقد سقط السيرفر من ساعات — حتى
      // يضغط المستخدم ↻ (فحص 2026-09-06).
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
      // الحارس: «فشل» وحدها تترك المالك يخمّن بين شبكة ورابط واعتماد.
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

/// محوّل يعيد حالة HTTP واحدة — بلا شبكة.
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
