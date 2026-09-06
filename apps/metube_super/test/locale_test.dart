import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';

/// **حارس م-50 (قرار المالك 2026-09-06): «اتبع لغة النظام» بابٌ يُفتح.**
///
/// `locale: null` في `app.dart` كان يتبع لغة الهاتف فعلاً، لكن أول لمسة
/// للمبدّل تثبّت لغةً **إلى الأبد**: لا خيار ثالث يعيد القيمة فارغة،
/// فالرجوع للتلقائي كان يحتاج حذف بيانات التطبيق — ومعها المكتبة
/// والمفضلة.
void main() {
  late MemoryKeyValueStore store;

  ProviderContainer makeContainer({String? initialLocale}) {
    store = MemoryKeyValueStore();
    return ProviderContainer(overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      secretStoreProvider.overrideWithValue(MemorySecretStore()),
      prefsMutexProvider.overrideWithValue(PrefsMutex()),
      initialSettingsProvider
          .overrideWithValue(SuperSettings(localeCode: initialLocale)),
    ]);
  }

  test('اختيار لغة يثبّتها في الحالة والتخزين', () async {
    final container = makeContainer();
    addTearDown(container.dispose);
    await container.read(settingsProvider.notifier).setLocale('en');

    expect(container.read(settingsProvider).localeCode, 'en');
    expect(await store.getString('app_locale'), 'en');
  });

  test('«النظام» يمحو اللغة المحفوظة — حالةً وتخزيناً', () async {
    final container = makeContainer(initialLocale: 'en');
    addTearDown(container.dispose);
    final notifier = container.read(settingsProvider.notifier);
    await notifier.setLocale('en');

    await notifier.setLocale(null);

    // **الحارس**: `copyWith` القديم كان `localeCode ?? this.localeCode`
    // فيبتلع الـnull ويُبقي 'en' — أي أن الخيار الثالث يبدو أنه يعمل
    // ولا يعمل. و`clearLocale` هو ما يميّز «امسح» عن «لا تغيّر».
    expect(container.read(settingsProvider).localeCode, isNull,
        reason: 'فارغ ⇒ MaterialApp يمرّر locale: null فيتبع الهاتف');
    expect(await store.getString('app_locale'), isNull,
        reason: 'ولا يعود بعد إعادة التشغيل');
  });

  test('التحميل من تخزين بلا مفتاح لغة ⇒ اتباع النظام', () async {
    final settings =
        await SuperSettings.load(MemoryKeyValueStore(), MemorySecretStore());
    expect(settings.localeCode, isNull);
  });
}
