import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../di.dart';
import 'setup_data.dart';

/// The server's addresses (at home, through a tunnel) and the one in use.
///
/// **Chosen by hand, never switched by itself** ([DesktopPolicy]): a
/// computer sits on one network for hours, and an address changing under
/// the user would surprise more than help. The addresses are saved on
/// this computer only; the password never is.
class ServerAddresses {
  const ServerAddresses({this.urls = const [], this.active});

  final List<String> urls;

  /// The address in use; null before any is chosen.
  final String? active;
}

/// Reads and writes [ServerAddresses], once at start-up and at each change.
class AddressesStore {
  const AddressesStore({required this.store, required this.mutex});

  final KeyValueStore store;
  final PrefsMutex mutex;

  static const _urlsKey = 'ember_server_addresses';
  static const _activeKey = 'ember_server_active';

  /// What was saved, with [seed] (the set-up address and any others it
  /// came with) when nothing was.
  Future<ServerAddresses> read({List<String> seed = const []}) async {
    final saved = await store.get(_urlsKey);
    final urls = saved is List ? saved.whereType<String>().toList() : seed;
    final active = await store.getString(_activeKey);
    return ServerAddresses(
      // Each once: a list saved by an older version held one address twice,
      // and both rows said "In use".
      urls: {...(urls.isEmpty ? seed : urls)}.toList(),
      active: active ?? seed.firstOrNull,
    );
  }

  Future<void> write(ServerAddresses addresses) => mutex.run(() async {
    await store.setStringList(_urlsKey, addresses.urls);
    if (addresses.active case final active?) {
      await store.setString(_activeKey, active);
    }
  });
}

/// The addresses as saved, read before the first frame so the first
/// request already goes to the chosen one. Overridden in main.
final initialAddressesProvider = Provider<ServerAddresses>(
  (ref) => const ServerAddresses(),
);

final addressesProvider = NotifierProvider<AddressesNotifier, ServerAddresses>(
  AddressesNotifier.new,
);

class AddressesNotifier extends Notifier<ServerAddresses> {
  @override
  ServerAddresses build() {
    final saved = ref.read(initialAddressesProvider);
    final setUp = ref.read(serverSetupProvider)?.baseUrl;
    return ServerAddresses(
      urls: {...saved.urls, ?setUp}.toList(),
      active: saved.active ?? setUp,
    );
  }

  /// Makes [url] the address in use: every request from now goes there.
  Future<void> use(String url) => _save(
    ServerAddresses(
      urls: [...state.urls, if (!state.urls.contains(url)) url],
      active: url,
    ),
  );

  /// Adds [url], cleaned of spaces and a trailing slash; false when it is
  /// not an address or is already there.
  Future<bool> add(String url) async {
    final clean = url.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(clean);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) return false;
    if (!{'http', 'https'}.contains(uri.scheme)) return false;
    if (state.urls.contains(clean)) return false;
    await _save(
      ServerAddresses(urls: [...state.urls, clean], active: state.active),
    );
    return true;
  }

  /// Removes [url]; the one in use stays, so there is always an address.
  Future<void> remove(String url) async {
    if (url == state.active) return;
    await _save(
      ServerAddresses(
        urls: [
          for (final u in state.urls)
            if (u != url) u,
        ],
        active: state.active,
      ),
    );
  }

  Future<void> _save(ServerAddresses next) {
    state = next;
    return AddressesStore(
      store: ref.read(keyValueStoreProvider),
      mutex: ref.read(prefsMutexProvider),
    ).write(next);
  }
}

/// How addresses are probed; a test puts its own in. The probe signs in as
/// the set-up account (Cloudflare pair included), so a refused password
/// reads as such.
final endpointResolverProvider = Provider<EndpointResolver>((ref) {
  final setup = ref.watch(serverSetupProvider);
  return EndpointResolver.withClientFactory(
    (url) =>
        MeTubeApiClient(config: setup?.at(url) ?? ServerConfig(baseUrl: url)),
  );
});

/// Each address's state, probed together when the section opens and when
/// "Test" is pressed. **Only the chosen one is ever used** ([fixed]): the
/// others are shown, never switched to.
final addressStatusesProvider =
    FutureProvider.autoDispose<Map<String, MTEndpointStatus>>((ref) async {
      final addresses = ref.watch(addressesProvider);
      if (addresses.urls.isEmpty) return const {};
      final found = await ref
          .watch(endpointResolverProvider)
          .resolveDetailed(
            externalUrls: addresses.urls,
            fixed: addresses.active,
          );
      return found.statuses;
    });
