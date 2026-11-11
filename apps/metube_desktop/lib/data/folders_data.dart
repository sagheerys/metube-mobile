import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../di.dart';
import '../identity.dart';

/// What this computer offers for folders: where they are by default, a
/// folder dialog, and Explorer. The Windows one is put in by main; the
/// default knows no folder and opens nothing, for tests.
abstract class DesktopFolders {
  const DesktopFolders();

  /// The user's Videos folder (moved by OneDrive or not).
  Future<String?> videos();

  /// The user's Downloads folder.
  Future<String?> downloads();

  /// Windows' folder dialog; null when it is closed without a choice.
  Future<String?> pick({String? initial});

  /// Windows' open dialog for one file of [extensions], read as text;
  /// null when it is closed or the file cannot be read.
  Future<String?> openText({required List<String> extensions});

  /// Windows' open dialog for several files of [extensions], each with its
  /// name and bytes; empty when it is closed or nothing could be read.
  Future<List<(String, List<int>)>> openFiles({
    required List<String> extensions,
  });

  /// Windows' save dialog, offering [name]; writes [text] where the user
  /// chose and returns that path, or null when it is closed.
  Future<String?> saveText({required String name, required String text});

  /// [saveText] for a file that is not text, a PDF say.
  Future<String?> saveBytes({required String name, required List<int> bytes});

  /// Opens Explorer on [path]'s folder with the file selected.
  Future<void> reveal(String path);

  /// Opens Explorer on the folder [path].
  Future<void> open(String path);

  /// Windows' "Open with" for the file at [path], so the user plays it in
  /// a player of their own (VLC, say); nothing where there is no Windows.
  ///
  /// **For a file on this computer only**: a server address handed to
  /// another player would carry the password in it, and could not carry a
  /// Cloudflare Access token at all.
  Future<void> openWith(String path) async {}
}

class NoFolders extends DesktopFolders {
  const NoFolders();

  @override
  Future<String?> videos() async => null;

  @override
  Future<String?> downloads() async => null;

  @override
  Future<String?> pick({String? initial}) async => null;

  @override
  Future<String?> openText({required List<String> extensions}) async => null;

  @override
  Future<List<(String, List<int>)>> openFiles({
    required List<String> extensions,
  }) async => const [];

  @override
  Future<String?> saveText({
    required String name,
    required String text,
  }) async => null;

  @override
  Future<String?> saveBytes({
    required String name,
    required List<int> bytes,
  }) async => null;

  @override
  Future<void> reveal(String path) async {}

  @override
  Future<void> open(String path) async {}
}

final desktopFoldersProvider = Provider<DesktopFolders>(
  (ref) => const NoFolders(),
);

/// The two folders (offline copies, own downloads), saved on this
/// computer only (a backup does
/// not carry them: another computer has other folders).
///
/// **Offline** is a copy the app knows and plays; **download** is a file
/// the user owns, which the app forgets once saved. Both stay on the
/// server.
class FolderSettings {
  const FolderSettings({
    this.offline,
    this.download,
    this.askEachTime = false,
    this.serverFolders = true,
  });

  /// Chosen by the user; null is the default below Videos.
  final String? offline;

  /// Chosen by the user; null is the default below Downloads.
  final String? download;

  /// Windows' folder dialog at each download instead of [download].
  final bool askEachTime;

  /// A download goes into the same folder it has on the server
  /// (`Downloads\MeTube Ember\Kids\clip.mp4`), so both are arranged alike.
  final bool serverFolders;

  FolderSettings copyWith({
    String? offline,
    String? download,
    bool? askEachTime,
    bool? serverFolders,
  }) => FolderSettings(
    offline: offline ?? this.offline,
    download: download ?? this.download,
    askEachTime: askEachTime ?? this.askEachTime,
    serverFolders: serverFolders ?? this.serverFolders,
  );
}

const _offlineKey = 'ember_offline_folder';
const _downloadKey = 'ember_download_folder';
const _askKey = 'ember_download_ask';
const _serverFoldersKey = 'ember_download_server_folders';

final folderSettingsProvider =
    NotifierProvider<FolderSettingsNotifier, FolderSettings>(
      FolderSettingsNotifier.new,
    );

class FolderSettingsNotifier extends Notifier<FolderSettings> {
  @override
  FolderSettings build() {
    _load();
    return const FolderSettings();
  }

  Future<void> _load() async {
    final store = ref.read(keyValueStoreProvider);
    try {
      final offline = await store.getString(_offlineKey);
      final download = await store.getString(_downloadKey);
      state = FolderSettings(
        offline: (offline?.isEmpty ?? true) ? null : offline,
        download: (download?.isEmpty ?? true) ? null : download,
        askEachTime: await store.getBool(_askKey) ?? false,
        serverFolders: await store.getBool(_serverFoldersKey) ?? true,
      );
    } on Object {
      // Unreadable settings are the defaults, never a failed start.
    }
  }

  Future<void> setOffline(String path) {
    state = state.copyWith(offline: path);
    return _save((s) => s.setString(_offlineKey, path));
  }

  Future<void> setDownload(String path) {
    state = state.copyWith(download: path);
    return _save((s) => s.setString(_downloadKey, path));
  }

  Future<void> setAskEachTime(bool on) {
    state = state.copyWith(askEachTime: on);
    return _save((s) => s.setBool(_askKey, on));
  }

  Future<void> setServerFolders(bool on) {
    state = state.copyWith(serverFolders: on);
    return _save((s) => s.setBool(_serverFoldersKey, on));
  }

  Future<void> _save(Future<void> Function(KeyValueStore store) write) => ref
      .read(prefsMutexProvider)
      .run(() => write(ref.read(keyValueStoreProvider)));
}

/// The offline folder in use: the chosen one, or
/// `Videos\MeTube Ember\Offline`: the app's own name, not
/// MeTube's, whose maker has nothing to do with this app.
final offlineFolderProvider = FutureProvider<String?>((ref) async {
  final chosen = ref.watch(folderSettingsProvider.select((s) => s.offline));
  if (chosen != null) return chosen;
  final videos = await ref.watch(desktopFoldersProvider).videos();
  return videos == null
      ? null
      : '$videos\\${EmberIdentity.displayName}\\Offline';
});

/// The download folder in use: the chosen one, or
/// `Downloads\MeTube Ember`.
final downloadFolderProvider = FutureProvider<String?>((ref) async {
  final chosen = ref.watch(folderSettingsProvider.select((s) => s.download));
  if (chosen != null) return chosen;
  final downloads = await ref.watch(desktopFoldersProvider).downloads();
  return downloads == null ? null : '$downloads\\${EmberIdentity.displayName}';
});
