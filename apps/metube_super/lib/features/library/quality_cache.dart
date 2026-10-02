import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

import '../../di.dart';
import 'media_probe.dart';

/// Each clip's quality, kept across launches (see [MediaQualityIndex]).
final mediaQualityIndexProvider = Provider(
  (ref) => MediaQualityIndex(
    store: ref.watch(keyValueStoreProvider),
    mutex: ref.watch(prefsMutexProvider),
  ),
);

final qualityReaderProvider = Provider((ref) => QualityReader(ref));

/// Reads a clip's quality from its header, and reads it ahead of time.
///
/// A header read from the server takes a moment, so waiting until the
/// details sheet opens means the user watches "reading" every time. A
/// finished download is read straight away instead, while nobody is
/// waiting, and the sheet then opens with the answer already stored.
class QualityReader {
  QualityReader(this._ref, {this._probe = const MediaProbe()});

  final Ref _ref;
  final MediaProbe _probe;

  /// The local copy when there is one, otherwise the server's stream — the
  /// same order the library's own probe uses.
  Future<MediaQuality?> read({String? localPath, String? serverFilename}) {
    if (localPath != null) return _probe.quality(path: localPath);
    if (serverFilename == null) return Future.value();
    final String url;
    try {
      url = _ref
          .read(playbackResolverProvider)
          .endpoint
          .buildUrl(serverFilename);
    } on UnsafeFilenameException {
      // A URL is never built for a filename that could escape the
      // download folder.
      return Future.value();
    }
    return _probe.quality(
      url: url,
      headers: _ref.read(apiClientProvider)?.streamingHeaders ?? const {},
    );
  }

  /// Reads and stores a just-finished download's quality, unless it is
  /// already known. Never throws: a download's completion must not fail
  /// over a detail the sheet can still read later.
  Future<void> prewarm(DownloadTask task) async {
    final url = task.canonicalUrl;
    final filename = task.serverFilename;
    if (url == null || url.isEmpty || filename == null) return;
    try {
      final index = _ref.read(mediaQualityIndexProvider);
      if (await index.valueOf(url) != null) return;
      final quality = await read(serverFilename: filename);
      if (quality != null) await index.remember(url, quality);
    } on Object {
      // Left unknown: the sheet reads it when it first opens.
    }
  }
}
