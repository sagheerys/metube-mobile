/// Where a chosen track's words come from, most trustworthy first.
enum TrackKind {
  /// Subtitles someone wrote.
  written,

  /// The speaker's own words, as recognised speech.
  spoken,

  /// A machine translation of the spoken words.
  translated,
}

/// The subtitle tracks a video offers, by yt-dlp's names.
class OfferedTracks {
  const OfferedTracks({this.written = const {}, this.automatic = const {}});

  final Set<String> written;
  final Set<String> automatic;
}

/// The track taken for one language.
class TrackChoice {
  const TrackChoice(this.language, this.track, this.kind);

  final String language;
  final String track;
  final TrackKind kind;
}

/// What a source delivered for one video.
class FetchedTracks {
  const FetchedTracks(this.texts, {this.translationsRefused = false});

  /// Subtitle file contents by track name. A track asked for and missing
  /// here was not delivered.
  final Map<String, String> texts;

  /// Translations were refused as too many requests; the video's own
  /// tracks still came.
  final bool translationsRefused;
}

/// Somewhere to fetch a video's subtitles from, off the MeTube server.
abstract interface class SubtitleSource {
  /// Lists what [url] offers, lets [choose] pick, and fetches the picks.
  ///
  /// Throws [BackfillRateLimited], [VideoGone] or [FetchFailed].
  Future<FetchedTracks> fetch(
    String url,
    List<TrackChoice> Function(OfferedTracks offered) choose,
  );
}

/// Too many requests: going on would only deepen the block.
class BackfillRateLimited implements Exception {
  const BackfillRateLimited(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Removed, private or otherwise gone for good.
class VideoGone implements Exception {
  const VideoGone(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Anything else; worth another try on the next run.
class FetchFailed implements Exception {
  const FetchFailed(this.message);
  final String message;
  @override
  String toString() => message;
}

/// What one run did.
class BackfillReport {
  int saved = 0;
  int alreadyDone = 0;
  int nothingOffered = 0;
  int gone = 0;
  int failed = 0;
  bool stoppedByRateLimit = false;
  bool translationsRefused = false;
}
