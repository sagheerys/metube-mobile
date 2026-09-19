import '../api/metube_api.dart';
import '../storage/key_value_store.dart';

/// **Is the server actually deleting the files, or only the rows?**
///
/// `DELETE_FILE_ON_TRASHCAN` defaults to `false` in MeTube (read from its
/// source, `ytdl.py`: the file is removed **only** when that variable is
/// true). Lite's whole promise rests on it, and without it the promise
/// fails in the quietest way there is: the history row goes, the app
/// reports success, the library looks right — and the disk fills up over
/// months until somebody goes looking.
///
/// It is the sixth of the ten ways found in the audit of 2026-09-19, and
/// the only one where **nothing is wrong with the app at all**. Which is
/// exactly why it has to be said out loud: the setup guide warns about it,
/// and whoever did not read the setup guide is precisely the person
/// affected.
///
/// The check is one range request for a file the server has just been told
/// to delete. Cheap, and conclusive: if it still serves, the file is still
/// there.
class TrashcanProbe {
  TrashcanProbe({required this.api, required this.store, required this.mutex});

  /// `true` once the server has been seen keeping a file it was told to
  /// delete. Never written back to false automatically: someone who fixes
  /// their container gets the flag cleared by the next successful check.
  static const String prefsKey = 'server_keeps_files';

  final MeTubeApi api;
  final KeyValueStore store;
  final PrefsMutex mutex;

  Future<bool> get serverKeepsFiles async => await store.get(prefsKey) == true;

  /// Call **after a delete the app believes succeeded**, with the filename
  /// that was supposed to go.
  ///
  /// Returns true when the server kept the file. Any doubt — no filename,
  /// a request that failed for its own reasons — returns false and writes
  /// nothing: a warning shown on a bad guess is worse than no warning,
  /// because it sends someone to change a setting that was already right.
  Future<bool> check(String? serverFilename) async {
    if (serverFilename == null || serverFilename.isEmpty) return false;
    final bool stillThere;
    try {
      stillThere = await api.fileExists(serverFilename);
    } on Object {
      return false;
    }
    await _remember(keepsFiles: stillThere);
    return stillThere;
  }

  Future<void> _remember({required bool keepsFiles}) async {
    if (await serverKeepsFiles == keepsFiles) return;
    await mutex.run(
      () => keepsFiles
          ? store.setBool(prefsKey, true)
          // The container was fixed: the warning goes with the cause.
          : store.remove(prefsKey),
    );
  }
}
