import '../urls/playlist_detector.dart';

/// One item inside a playlist preview, on the batch screen.
class PlaylistTrack {
  const PlaylistTrack({
    required this.url,
    required this.title,
    this.duration,
    this.thumbnail,
  });

  final String url;
  final String title;
  final Duration? duration;
  final String? thumbnail;
}

/// A playlist preview as the batch screen shows it: the title, the cover
/// and the items with their durations. Built by the YouTube or SoundCloud
/// resolver.
class PlaylistPreview {
  const PlaylistPreview({
    required this.kind,
    required this.title,
    this.coverUrl,
    this.tracks = const [],
  });

  final PlaylistKind kind;
  final String title;
  final String? coverUrl;
  final List<PlaylistTrack> tracks;

  Duration get totalDuration => tracks.fold(
    Duration.zero,
    (sum, t) => sum + (t.duration ?? Duration.zero),
  );
}
