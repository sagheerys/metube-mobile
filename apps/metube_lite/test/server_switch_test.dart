import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';

/// What the app learned about one server does not follow it to another.
///
/// Plain `test`s on purpose, in a file of their own: a widget test swaps the
/// HTTP client for one that answers 400, and saving a server tests the
/// connection for real, here against a tiny MeTube stand-in on loopback.
void main() {
  late HttpServer server;
  late String base;
  late MemoryKeyValueStore store;
  late ProviderContainer container;

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://${server.address.host}:${server.port}';
    server.listen((request) {
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'done': [], 'queue': [], 'pending': []}))
        ..close();
    });
    store = MemoryKeyValueStore();
    container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(
          LiteSettings(serverUrl: base),
        ),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await server.close(force: true);
  });

  test('another server drops the "keeps deleted files" warning', () async {
    // Defect: a warning learned on a test server stayed on the settings
    // screen after switching back to a server that deletes its files.
    await store.setBool(TrashcanProbe.prefsKey, true);
    await container
        .read(settingsProvider.notifier)
        .saveServer(url: '$base/other');
    expect(await store.get(TrashcanProbe.prefsKey), isNull);
  });

  test('saving the same server again keeps what was learned', () async {
    await store.setBool(TrashcanProbe.prefsKey, true);
    await container.read(settingsProvider.notifier).saveServer(url: base);
    expect(await store.get(TrashcanProbe.prefsKey), isTrue);
  });
}
