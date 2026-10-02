import 'package:mt_core/mt_core.dart';

/// The clips the server was asked for a subtitle file and had none:
/// canonicalUrl to the media filename that was checked.
///
/// A miss is final for that filename (see `SidecarOutcome.none`), so it is
/// kept across launches rather than asked again at every library refresh:
/// a library of hundreds of older clips would otherwise cost hundreds of
/// 404s a day. The filename is stored, not a flag, so a clip downloaded
/// again under the same URL, to a new file, is checked once more.
/// Storage key: `transcript_sidecar_misses`.
final class SidecarMissIndex extends UrlKeyedIndex<String> {
  SidecarMissIndex({required super.store, required super.mutex})
    : super(prefsKey: 'transcript_sidecar_misses');

  @override
  String? decodeValue(dynamic raw) => raw is String ? raw : null;

  @override
  dynamic encodeValue(String value) => value;

  /// Whether [filename] is the one already found missing for [canonicalUrl].
  static bool covers(
    Map<String, String> misses,
    String canonicalUrl,
    String filename,
  ) => misses[canonicalUrl] == filename;
}
