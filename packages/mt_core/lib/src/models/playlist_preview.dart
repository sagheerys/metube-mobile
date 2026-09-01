import '../urls/playlist_detector.dart';

/// عنصر واحد داخل معاينة قائمة (شاشة الدفعي م-11).
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

/// معاينة قائمة تشغيل كما تعرضها شاشة الدفعي: العنوان والغلاف والعناصر
/// بمددها — يبنيها resolver YouTube أو SoundCloud.
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
