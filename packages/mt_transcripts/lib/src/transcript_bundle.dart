import 'dart:convert';

import 'transcript.dart';

/// Every transcript in one file, for an export the user keeps and an
/// import that restores it on a new phone.
///
/// Kept apart from the settings backup on purpose: that one is rewritten
/// on every change and rotated seven times, and transcripts would multiply
/// its size by seven for no gain.
abstract final class TranscriptBundle {
  static const kind = 'mtf-transcripts';
  static const version = 1;

  static String encode(Iterable<Transcript> transcripts) => jsonEncode({
    'kind': kind,
    'version': version,
    'transcripts': [for (final t in transcripts) t.toJson()],
  });

  /// The transcripts in [raw], or null when it is not a transcripts file at
  /// all — a settings backup picked by mistake, say. Entries this code
  /// cannot read are skipped, not fatal.
  static List<Transcript>? decode(String raw) {
    final Object? json;
    try {
      json = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (json is! Map || json['kind'] != kind) return null;
    final list = json['transcripts'];
    if (list is! List) return null;
    return [for (final entry in list) ?Transcript.fromJson(entry)];
  }
}
