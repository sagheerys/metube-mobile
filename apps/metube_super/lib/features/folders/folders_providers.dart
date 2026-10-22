import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';
import '../library/library_providers.dart';

/// The folders the server would save into, asked for when a picker opens
/// and forgotten when it closes, so a folder made on the server since then
/// shows the next time.
final serverFoldersProvider = FutureProvider.autoDispose<ServerFolders?>((
  ref,
) async {
  final api = ref.watch(apiClientProvider);
  return api?.fetchFolders();
});

/// **Every folder the picker can offer**, for video or for audio: what the
/// server lists, and the folders the library's clips sit in, with each
/// one's parents, so a server that does not list its folders still offers
/// the ones in use. In tree order, a parent before what is inside it.
List<String> pickableFolders(
  ServerFolders? server,
  Iterable<String> fromLibrary, {
  required bool audio,
}) {
  final all = <String>{};
  void add(String path) {
    final parts = ServerPath.cleanFolder(path).split('/');
    for (var i = 1; i <= parts.length; i++) {
      final prefix = parts.take(i).join('/');
      if (prefix.isNotEmpty) all.add(prefix);
    }
  }

  for (final path in server?.of(audio: audio) ?? const <String>[]) {
    add(path);
  }
  fromLibrary.forEach(add);
  int byTree(String a, String b) {
    final x = a.toLowerCase().split('/');
    final y = b.toLowerCase().split('/');
    for (var i = 0; i < x.length && i < y.length; i++) {
      final c = x[i].compareTo(y[i]);
      if (c != 0) return c;
    }
    return x.length.compareTo(y.length);
  }

  return all.toList()..sort(byTree);
}

/// The folders the library's clips sit in.
final libraryFolderPathsProvider = Provider<Set<String>>((ref) {
  final items = ref.watch(libraryItemsProvider).valueOrNull ?? const [];
  return {for (final item in items) ?item.folderPath};
});

/// **The server saves at the top whatever folder is asked for.** Its
/// `YTDL_OPTIONS` carries an absolute `outtmpl`, which overrides the
/// folder; MeTube then reports the file as `Folder/../name`. Seen in the
/// history it is certain, and the picker says so rather than let a choice
/// look as if it worked.
final foldersIgnoredProvider = Provider<bool>((ref) {
  final done = ref.watch(historyProvider).valueOrNull?.done ?? const [];
  return done.any(
    (item) =>
        (item.folder?.isNotEmpty ?? false) &&
        (item.filename?.startsWith('../') ?? false),
  );
});
