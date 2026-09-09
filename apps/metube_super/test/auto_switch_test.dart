import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/auto_switch.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';

/// An endpoint-switching regression: **it had never been implemented at
/// all**. There was no network listener, and `adoptActiveUrl` was called
/// only by a manual tap. A real device was streaming through the tunnel
/// while on the same network as the server (41x slower by measurement).
void main() {
  // `start()` registers an `AppLifecycleListener`; the app returning to the
  // foreground is a trigger.
  TestWidgetsFlutterBinding.ensureInitialized();

  const local = 'http://192.168.1.10:8086';
  const tunnel = 'https://metube.example.com';

  /// A container with settings configured and a resolver returning whatever
  /// we decide for each endpoint.
  (ProviderContainer, MemoryKeyValueStore) build({
    required Set<String> reachable,
    String activeUrl = tunnel,
    bool autoSwitch = true,
  }) {
    final store = MemoryKeyValueStore();
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(
          SuperSettings(
            localUrl: local,
            externalUrls: const [tunnel],
            activeUrl: activeUrl,
            autoSwitch: autoSwitch,
            themeMode: ThemeMode.system,
          ),
        ),
        endpointResolverProvider.overrideWithValue(
          EndpointResolver(
            probe: (url) async => reachable.contains(url)
                ? MTEndpointStatus.ok
                : MTEndpointStatus.unreachable,
          ),
        ),
        // Probing now asks the engine "is anything in flight?" before
        // switching (defect ع-1), and the engine needs the logger, which is
        // overridden in main and so is overridden here too.
        loggerProvider.overrideWithValue(
          MTLogger(filePath: '${Directory.systemTemp.path}/mtf_test.log'),
        ),
      ],
    );
    addTearDown(container.dispose);
    return (container, store);
  }

  test('a network change adopts the local URL over the tunnel', () async {
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
    // The adopted endpoint is actually used to build the client, not just
    // held in state.
    expect(container.read(settingsProvider).serverConfig?.baseUrl, local);
  });

  test(
    'leaving the home network: the local URL drops and the tunnel is adopted',
    () async {
      final (container, store) = build(reachable: {tunnel}, activeUrl: local);
      final service = AutoSwitchService(
        _RefFor(container),
        networkChanges: const Stream.empty(),
        debounce: Duration.zero,
      );
      await service.resolveNow();
      expect(container.read(settingsProvider).activeUrl, tunnel);
      expect(await store.getString('active_url'), tunnel);
    },
  );

  test('an active URL no longer among the candidates is corrected', () async {
    // A regression: editing the endpoint list left the app on a deleted
    // address.
    final (container, _) = build(
      reachable: {tunnel},
      activeUrl: 'http://192.168.1.10:8086',
    );
    await container
        .read(settingsProvider.notifier)
        .setLocalUrl('http://192.168.1.99:8086'); // a dead address
    final service = AutoSwitchService(
      _RefFor(container),
      networkChanges: const Stream.empty(),
      debounce: Duration.zero,
    );
    await service.resolveNow();
    expect(container.read(settingsProvider).activeUrl, tunnel);
  });

  test('when nothing responds, the active URL is **not** cleared', () async {
    final (container, _) = build(reachable: const {});
    final service = AutoSwitchService(
      _RefFor(container),
      networkChanges: const Stream.empty(),
      debounce: Duration.zero,
    );
    await service.resolveNow();
    expect(container.read(settingsProvider).activeUrl, tunnel);
  });

  test('with switching off, the active URL is left alone', () async {
    final (container, _) = build(reachable: {local, tunnel}, autoSwitch: false);
    final service = AutoSwitchService(
      _RefFor(container),
      networkChanges: const Stream.empty(),
      debounce: Duration.zero,
    );
    await service.resolveNow();
    expect(container.read(settingsProvider).activeUrl, tunnel);
  });

  group(
    'seeding the URL list from an install configured with a single URL',
    () {
      test('a private address is recorded as the local URL', () async {
        final store = MemoryKeyValueStore();
        await seedEndpointsFromActive(
          store,
          PrefsMutex(),
          const SuperSettings(activeUrl: local),
        );
        expect(await store.getString('local_url'), local);
        expect(await store.getStringList('external_urls'), isNull);
      });

      test('a public domain is recorded as an external URL', () async {
        final store = MemoryKeyValueStore();
        await seedEndpointsFromActive(
          store,
          PrefsMutex(),
          const SuperSettings(activeUrl: tunnel),
        );
        expect(await store.getStringList('external_urls'), [tunnel]);
        expect(await store.getString('local_url'), isNull);
      });

      test('an existing list is left untouched', () async {
        final store = MemoryKeyValueStore();
        await seedEndpointsFromActive(
          store,
          PrefsMutex(),
          const SuperSettings(
            localUrl: local,
            activeUrl: tunnel,
            externalUrls: [tunnel],
          ),
        );
        expect(await store.getStringList('external_urls'), isNull);
      });
    },
  );

  group('isPrivateHostUrl', () {
    test('private addresses', () {
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

    test('public addresses', () {
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

/// [AutoSwitchService] needs a `Ref` for reading only, so the container is
/// enough.
class _RefFor implements Ref {
  _RefFor(this._container);

  final ProviderContainer _container;

  @override
  T read<T>(ProviderListenable<T> provider) => _container.read(provider);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName} غير مستعمل');
}
