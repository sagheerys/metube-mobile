import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../di.dart';
import 'addresses_data.dart';

/// Where the password and user name are kept: Windows' own encrypted
/// store, put in by main; in memory for tests.
final secretStoreProvider = Provider<SecretStore>((ref) => MemorySecretStore());

/// The server set up on this computer: its address in the settings, and
/// its user name, password and Cloudflare pair in [SecretStore], never in
/// the settings file, a backup or a log.
class ServerSetupStore {
  const ServerSetupStore({
    required this.store,
    required this.secrets,
    required this.mutex,
  });

  final KeyValueStore store;
  final SecretStore secrets;
  final PrefsMutex mutex;

  static const _urlKey = 'ember_server_url';

  Future<ServerConfig?> read() async {
    final url = await store.getString(_urlKey);
    if (url == null || url.isEmpty) return null;
    return ServerConfig(
      baseUrl: url,
      username: await secrets.read(SecretKeys.username),
      password: await secrets.read(SecretKeys.password),
      access: await CloudflareAccess.load(secrets),
    );
  }

  Future<void> write(ServerConfig config) async {
    await mutex.run(() => store.setString(_urlKey, config.baseUrl));
    for (final (key, value) in [
      (SecretKeys.username, config.username),
      (SecretKeys.password, config.password),
    ]) {
      if (value == null || value.isEmpty) {
        await secrets.delete(key);
      } else {
        await secrets.write(key, value);
      }
    }
    await CloudflareAccess.save(secrets, config.access);
  }
}

/// Whether the setup opens by itself at a start with no server: the real
/// app's first run. Off by default, so a test of an empty shell sees the
/// shell.
final offerSetupAtStartProvider = Provider<bool>((ref) => false);

/// The set-up server as start-up found it (the lab file in a debug build,
/// else what was saved), read before the first frame. Overridden in main.
final initialServerSetupProvider = Provider<ServerConfig?>((ref) => null);

/// The account to sign in with and the address it was set up on; null
/// until the first-run setup has one.
final serverSetupProvider =
    NotifierProvider<ServerSetupNotifier, ServerConfig?>(
      ServerSetupNotifier.new,
    );

class ServerSetupNotifier extends Notifier<ServerConfig?> {
  @override
  ServerConfig? build() => ref.read(initialServerSetupProvider);

  /// Keeps [config], already tested, as this computer's server, and makes
  /// its address the one in use.
  Future<void> save(ServerConfig config) async {
    await ServerSetupStore(
      store: ref.read(keyValueStoreProvider),
      secrets: ref.read(secretStoreProvider),
      mutex: ref.read(prefsMutexProvider),
    ).write(config);
    state = config;
    await ref.read(addressesProvider.notifier).use(config.baseUrl);
  }
}
