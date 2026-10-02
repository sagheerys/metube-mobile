import 'package:mt_core/mt_core.dart';

import 'subtitle_parser.dart';
import 'transcript.dart';

enum SidecarOutcome {
  /// A file was there and read; the transcript is in [SidecarResult.transcript].
  found,

  /// The server holds no subtitle file for that clip and language. Final
  /// for that filename: a clip's subtitles are written before its media,
  /// so one that is missing once never appears later.
  none,

  /// The server could not be asked. Nothing is known, and asking again
  /// later is right.
  failed,
}

class SidecarResult {
  const SidecarResult(this.outcome, {this.transcript});

  final SidecarOutcome outcome;
  final Transcript? transcript;
}

/// Subtitles the server wrote **beside** a clip, read back from `/download`.
///
/// A MeTube whose `YTDL_OPTIONS` carries `writesubtitles` (the setup guide
/// shows the line) has yt-dlp save each clip's subtitles next to its file,
/// whoever asked for the clip: the app, a subscription, the web page. That
/// covers what [CaptionsFetcher] cannot: it only acts before a clip the app
/// itself adds, since asking the server for an existing clip's subtitles
/// replaces the clip's own record.
///
/// yt-dlp names the subtitle file after the media file, with the extension
/// replaced by `<language>.<format>`, so the name is computed from the
/// clip's `filename` in `/history` and no folder is ever listed. Measured
/// on a real server (MeTube 2026.09.25) for a video and for an audio
/// download alike: `Me at the zoo [jNQXAC9IVRw].en.vtt` beside the `.webm`
/// and beside the `.m4a`.
class SidecarReader {
  const SidecarReader(this.api);

  final MeTubeApi api;

  /// The names the file can have, most likely first: `vtt` is what YouTube
  /// serves and what the guide asks for, `srt` what a converter leaves.
  static List<String> namesFor(String filename, String language) {
    final dot = filename.lastIndexOf('.');
    final stem = dot <= 0 ? filename : filename.substring(0, dot);
    return ['$stem.$language.vtt', '$stem.$language.srt'];
  }

  Future<SidecarResult> read({
    required String canonicalUrl,
    required String filename,
    required String language,
  }) async {
    // A name that could leave the download folder is never sent, nor any
    // name derived from it; the media's own name was already refused for
    // the same reason.
    if (!UrlKit.isSafeServerFilename(filename)) {
      return const SidecarResult(SidecarOutcome.none);
    }
    for (final name in namesFor(filename, language)) {
      if (!UrlKit.isSafeServerFilename(name)) break;
      final String text;
      try {
        text = await api.fetchText(name);
      } on NoApiException {
        continue; // 404: not under this name
      } on MTApiException {
        return const SidecarResult(SidecarOutcome.failed);
      }
      final segments = SubtitleParser.parse(text);
      if (segments.isEmpty) continue;
      return SidecarResult(
        SidecarOutcome.found,
        transcript: Transcript(
          canonicalUrl: canonicalUrl,
          language: language,
          // The same subtitles the captions job fetches, only written by
          // the server on its own; the rest of the app need not tell them
          // apart.
          source: 'captions',
          fetchedAt: DateTime.now(),
          segments: segments,
        ),
      );
    }
    return const SidecarResult(SidecarOutcome.none);
  }
}
