import 'package:mt_core/mt_core.dart';

import 'sidecar_listing.dart';
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
/// A MeTube whose `YTDL_OPTIONS` carries `writesubtitles` (docs/SERVER-SETUP.md
/// shows the line) has yt-dlp save each clip's subtitles next to its file,
/// whoever asked for the clip: the app, a subscription, the web page. That
/// covers what [CaptionsFetcher] cannot: it only acts before a clip the app
/// itself adds, since asking the server for an existing clip's subtitles
/// replaces the clip's own record.
///
/// yt-dlp names the subtitle file after the media file, with the extension
/// replaced by `<track>.<format>`, so the name is derived from the clip's
/// `filename` in `/history`. Measured on a real server (MeTube 2026.09.25)
/// for a video and for an audio download alike: `Me at the zoo
/// [jNQXAC9IVRw].en.vtt` beside the `.webm` and beside the `.m4a`.
///
/// The track is the language alone on most clips, but not on one with
/// several audio tracks, where YouTube suffixes it (`en-nP7-2PuUl7o`,
/// measured 2026-10-03). So with a [SidecarListing] of the folder the file
/// is picked among the names beside the clip, by language; without one,
/// the plain names are tried.
class SidecarReader {
  const SidecarReader(this.api, {this.listing});

  final MeTubeApi api;
  final SidecarListing? listing;

  /// The names the file can have when the track is the plain language,
  /// most likely first: `vtt` is what YouTube serves and what docs/SERVER-SETUP.md
  /// asks for, `srt` what a converter leaves.
  static List<String> namesFor(String filename, String language) {
    final stem = SidecarListing.stemOf(filename);
    return ['$stem.$language.vtt', '$stem.$language.srt'];
  }

  /// The files beside [filename] that hold [language], best first: the
  /// language alone, then the clip's own tracks under a suffix, then a
  /// translation into it (`ar-en-…`), which costs nothing to read once the
  /// server has it.
  static List<String> choose(
    SidecarListing listing,
    String filename,
    String language,
  ) {
    final beside = listing.besides(filename);
    int rank(String label) {
      final lower = label.toLowerCase();
      if (lower == language || lower == '$language-orig') return 0;
      if (lower.startsWith('$language-$language-')) return 1;
      if (!lower.startsWith('$language-')) return -1;
      final next = label.substring(language.length + 1).split('-').first;
      // A translation names its source language second, in lower case; a
      // region is upper case (`en-US`) and a track id mixes cases, as
      // `nP7-2PuUl7o` does.
      final translated = RegExp(r'^[a-z]{2,3}$').hasMatch(next);
      return translated ? 3 : 2;
    }

    final ranked = [
      for (final (label, name) in beside)
        if (rank(label) case final r when r >= 0) (r, name),
    ]..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2.compareTo(b.$2));
    return [for (final (_, name) in ranked) name];
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
    final names = switch (listing) {
      final listing? => choose(listing, filename, language),
      null => namesFor(filename, language),
    };
    for (final name in names) {
      if (!UrlKit.isSafeServerFilename(name)) continue;
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
          // What was asked for, not the track's own label: a clip holds
          // one transcript per language asked, as the captions job does.
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
