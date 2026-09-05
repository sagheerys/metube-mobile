import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/auto_switch.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';

/// انحدار م-28/ر-9 — **التبديل التلقائي لم يكن منفَّذاً أصلاً**: لا مستمع
/// شبكة، و`adoptActiveUrl` لا يُستدعى إلا بنقرة يدوية. جهاز المالك كان
/// يبث عبر النفق وهو على نفس شبكة السيرفر (أبطأ ٤١× بالقياس).
void main() {
  // `start()` يسجّل `AppLifecycleListener` (عودة التطبيق للمقدمة محفّز).
  TestWidgetsFlutterBinding.ensureInitialized();

  const local = 'http://192.168.1.10:8086';
  const tunnel = 'https://metube.example.com';

  /// حاوية بإعدادات مهيأة ومحلّل يُرجع ما نقرره لكل رابط.
  (ProviderContainer, MemoryKeyValueStore) build({
    required Set<String> reachable,
    String activeUrl = tunnel,
    bool autoSwitch = true,
  }) {
    final store = MemoryKeyValueStore();
    final container = ProviderContainer(overrides: [
      keyValueStoreProvider.overrideWithValue(store),
      prefsMutexProvider.overrideWithValue(PrefsMutex()),
      initialSettingsProvider.overrideWithValue(SuperSettings(
        localUrl: local,
        externalUrls: const [tunnel],
        activeUrl: activeUrl,
        autoSwitch: autoSwitch,
        themeMode: ThemeMode.system,
      )),
      endpointResolverProvider.overrideWithValue(
        EndpointResolver(
            probe: (url) async => reachable.contains(url)
                ? MTEndpointStatus.ok
                : MTEndpointStatus.unreachable),
      ),
      // الفحص صار يسأل المحرك «هل من عمل جارٍ؟» قبل التبديل (ع-1)،
      // والمحرك يحتاج السجل — يُتجاوز في main، فيُتجاوز هنا كذلك.
      loggerProvider.overrideWithValue(
        MTLogger(filePath: '${Directory.systemTemp.path}/mtf_test.log'),
      ),
    ]);
    addTearDown(container.dispose);
    return (container, store);
  }

  test('تغيّر الشبكة يعتمد المحلي تلقائياً بدل النفق', () async {
    final (container, store) = build(reachable: {local, tunnel});
    final changes = StreamController<Object?>.broadcast();
    addTearDown(changes.close);

    final service = AutoSwitchService(
      _RefFor(container),
      networkChanges: changes.stream,
      debounce: Duration.zero,
    )..start();
    addTearDown(service.dispose);

    await service.resolveNow();
    expect(container.read(settingsProvider).activeUrl, local);
    expect(await store.getString('active_url'), local);
    // الرابط المعتمد يُستعمل فعلاً في بناء العميل (لا في الحالة وحدها).
    expect(container.read(settingsProvider).serverConfig?.baseUrl, local);
  });

  test('خروج من الشبكة المنزلية: المحلي يسقط ⇒ يعتمد النفق', () async {
    final (container, store) =
        build(reachable: {tunnel}, activeUrl: local);
    final service = AutoSwitchService(_RefFor(container),
        networkChanges: const Stream.empty(), debounce: Duration.zero);
    await service.resolveNow();
    expect(container.read(settingsProvider).activeUrl, tunnel);
    expect(await store.getString('active_url'), tunnel);
  });

  test('المعتمد لم يعد من المرشحين (عُدّل الرابط) ⇒ يُصحَّح', () async {
    // انحدار: تعديل قائمة الروابط كان يترك التطبيق على عنوان محذوف.
    final (container, _) = build(
      reachable: {tunnel},
      activeUrl: 'http://192.168.1.10:8086',
    );
    await container
        .read(settingsProvider.notifier)
        .setLocalUrl('http://192.168.1.99:8086'); // عنوان ميت
    final service = AutoSwitchService(_RefFor(container),
        networkChanges: const Stream.empty(), debounce: Duration.zero);
    await service.resolveNow();
    expect(container.read(settingsProvider).activeUrl, tunnel);
  });

  test('لا شيء يستجيب ⇒ **لا يُصفَّر** الرابط المعتمد', () async {
    final (container, _) = build(reachable: const {});
    final service = AutoSwitchService(_RefFor(container),
        networkChanges: const Stream.empty(), debounce: Duration.zero);
    await service.resolveNow();
    expect(container.read(settingsProvider).activeUrl, tunnel);
  });

  test('التبديل مُطفأ ⇒ لا يمس الرابط المعتمد', () async {
    final (container, _) =
        build(reachable: {local, tunnel}, autoSwitch: false);
    final service = AutoSwitchService(_RefFor(container),
        networkChanges: const Stream.empty(), debounce: Duration.zero);
    await service.resolveNow();
    expect(container.read(settingsProvider).activeUrl, tunnel);
  });

  group('بذرة قائمة الروابط (تثبيت هُيّئ برابط واحد)', () {
    test('عنوان شبكة خاصة ⇒ يُسجَّل رابطاً محلياً', () async {
      final store = MemoryKeyValueStore();
      await seedEndpointsFromActive(store, PrefsMutex(),
          const SuperSettings(activeUrl: local));
      expect(await store.getString('local_url'), local);
      expect(await store.getStringList('external_urls'), isNull);
    });

    test('نطاق عام ⇒ يُسجَّل رابطاً خارجياً', () async {
      final store = MemoryKeyValueStore();
      await seedEndpointsFromActive(store, PrefsMutex(),
          const SuperSettings(activeUrl: tunnel));
      expect(await store.getStringList('external_urls'), [tunnel]);
      expect(await store.getString('local_url'), isNull);
    });

    test('قائمة موجودة ⇒ لا تُمس', () async {
      final store = MemoryKeyValueStore();
      await seedEndpointsFromActive(
        store,
        PrefsMutex(),
        const SuperSettings(
            localUrl: local, activeUrl: tunnel, externalUrls: [tunnel]),
      );
      expect(await store.getStringList('external_urls'), isNull);
    });
  });

  group('isPrivateHostUrl', () {
    test('العناوين الخاصة', () {
      for (final url in const [
        'http://192.168.1.10:8086',
        'http://10.0.0.5',
        'http://172.16.3.1',
        'http://172.31.255.1',
        'http://127.0.0.1:8086',
        'http://localhost:8086',
        'http://nas.local',
        'http://metube',
      ]) {
        expect(isPrivateHostUrl(url), isTrue, reason: url);
      }
    });

    test('العناوين العامة', () {
      for (final url in const [
        'https://metube.example.com',
        'http://172.32.0.1',
        'http://8.8.8.8',
        'http://172.15.0.1',
      ]) {
        expect(isPrivateHostUrl(url), isFalse, reason: url);
      }
    });
  });
}

/// [AutoSwitchService] يحتاج `Ref` للقراءة فقط — الحاوية تكفي.
class _RefFor implements Ref {
  _RefFor(this._container);

  final ProviderContainer _container;

  @override
  T read<T>(ProviderListenable<T> provider) => _container.read(provider);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} غير مستعمل');
}
