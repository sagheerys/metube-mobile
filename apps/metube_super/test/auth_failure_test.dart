import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/app.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/library_providers.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import 'playback_test_doubles.dart';

/// **حرّاس بلاغ المالك 2026-09-05**: قفل سيرفر Super خلف كلاودفلير،
/// فصار التطبيق **شاشة رمادية فارغة** لا رسالة فيها.
///
/// الجذر لم يكن الشبكة: `AsyncError.value` في Riverpod **يعيد رمي
/// الخطأ**، والنمط `AsyncValue(:final value?)` في أول فروع المكتبة
/// يقرأ ذلك الـgetter — فينفجر البناء **قبل** أن يُبلَغ فرع
/// `AsyncError()` المكتوب بعده بأسطر. أي أن معالجة الخطأ كانت موجودة
/// وغير قابلة للوصول.
void main() {
  late MemoryKeyValueStore store;
  late PrefsMutex mutex;
  late MTAudioHandler handler;

  setUp(() {
    store = MemoryKeyValueStore();
    mutex = PrefsMutex();
    handler = MTAudioHandler(
      player: FakeMediaPlayer(),
      resolver: PlaybackSourceResolver(
        endpoint: ServerStreamEndpoint.none,
        fileExists: (_) => false,
      ),
      positions: PlaybackPositionStore(store: store, mutex: mutex),
      prefs: PlaybackPrefs(store: store, mutex: mutex),
      stateStore: AudioStateStore(store: store, mutex: mutex),
      saveInterval: const Duration(hours: 1),
    );
  });

  tearDown(() => handler.dispose());

  /// تطبيق مهيَّأ بسيرفر، ومكتبته تفشل بالخطأ المعطى.
  Widget appFailingWith(Object error) => ProviderScope(
    overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      secretStoreProvider.overrideWithValue(MemorySecretStore()),
      prefsMutexProvider.overrideWithValue(mutex),
      initialSettingsProvider.overrideWithValue(
        const SuperSettings(
          activeUrl: 'https://mtube.example.com',
          localeCode: 'ar',
        ),
      ),
      playbackResolverProvider.overrideWithValue(handler.resolver),
      audioHandlerProvider.overrideWithValue(handler),
      loggerProvider.overrideWithValue(
        MTLogger(filePath: '${Directory.systemTemp.path}/mtf_auth.log'),
      ),
      libraryItemsProvider.overrideWith((ref) async => throw error),
    ],
    child: const SuperApp(),
  );

  Future<MTLocalizations> arabic() =>
      MTLocalizations.delegate.load(const Locale('ar'));

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('رفض الاعتماد (401) ⇒ رسالة تقول سببه لا شاشة رمادية', (
    tester,
  ) async {
    await tester.pumpWidget(appFailingWith(const AuthFailureException('401')));
    await settle(tester);

    // **الحارس الأول**: البناء لا ينفجر. على الكود القديم كان
    // `AsyncError.value` يرمي هنا فتُستبدل الشاشة كلها بمربع
    // `ErrorWidget` الرمادي (رماديّ في وضع الإصدار، بلا نصّ).
    expect(tester.takeException(), isNull);

    // **الحارس الثاني**: السبب معلن، وفيه طريق للإصلاح.
    final l10n = await arabic();
    expect(find.text(l10n.signInRequired), findsOneWidget);
    expect(find.text(l10n.updateCredentials), findsOneWidget);
  });

  testWidgets('عطل شبكة ⇒ رسالة الشبكة لا رسالة الاعتماد', (tester) async {
    await tester.pumpWidget(appFailingWith(const NetworkException('down')));
    await settle(tester);

    expect(tester.takeException(), isNull);
    final l10n = await arabic();
    // التمييز مقصود: «حدّث كلمة المرور» تشخيص خاطئ لانقطاع الشبكة،
    // تماماً كما أن «تعذّر الوصول» تشخيص خاطئ لرفض الاعتماد.
    expect(find.text(l10n.signInRequired), findsNothing);
    expect(find.text(l10n.connectionFailed), findsOneWidget);
    expect(find.text(l10n.errNetwork), findsOneWidget);
  });
}
