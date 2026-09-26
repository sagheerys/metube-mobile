/// **What a file actually is**, read from its own header (asked
/// 2026-09-25: the item details should say the video and audio quality).
///
/// The server records the quality a download was *asked* for — usually
/// "best" — never what it *got*. And the difference matters: "best" can
/// be 4K in AV1, which a phone without an AV1 decoder cannot play in
/// hardware, and nothing on screen said so. The header says the
/// resolution, the codec and the frame rate; this class holds them and
/// turns them into words.
///
/// Every field may be missing: a header that does not declare a frame
/// rate, a stream that could not be reached, a container the platform
/// cannot parse.
class MediaQuality {
  const MediaQuality({
    this.width,
    this.height,
    this.videoMime,
    this.frameRate,
    this.audioMime,
    this.sampleRate,
    this.channels,
  });

  /// From the platform's map; unknown keys and wrong types are ignored.
  factory MediaQuality.fromMap(Map<Object?, Object?> raw) {
    int? integer(String key) => switch (raw[key]) {
      final num n when n > 0 => n.round(),
      _ => null,
    };
    String? text(String key) => switch (raw[key]) {
      final String s when s.trim().isNotEmpty => s.trim(),
      _ => null,
    };
    return MediaQuality(
      width: integer('width'),
      height: integer('height'),
      videoMime: text('videoMime'),
      frameRate: integer('frameRate'),
      audioMime: text('audioMime'),
      sampleRate: integer('sampleRate'),
      channels: integer('channels'),
    );
  }

  /// As displayed: after the recorded rotation.
  final int? width;
  final int? height;
  final String? videoMime;
  final int? frameRate;
  final String? audioMime;
  final int? sampleRate;
  final int? channels;

  bool get hasVideo => videoMime != null || (width != null && height != null);
  bool get hasAudio => audioMime != null;
  bool get isEmpty => !hasVideo && !hasAudio;

  /// The name people use for a resolution, from the **shorter** side: a
  /// vertical 1080×1920 clip is 1080p, not 1920p, and 4096×2160 is 4K.
  String? get resolutionLabel {
    final w = width, h = height;
    if (w == null || h == null) return null;
    final side = w < h ? w : h;
    return switch (side) {
      >= 4320 => '8K',
      >= 2160 => '4K',
      >= 1440 => '1440p',
      >= 1080 => '1080p',
      >= 720 => '720p',
      >= 480 => '480p',
      >= 360 => '360p',
      _ => '${side}p',
    };
  }

  String? get videoCodec => _codecName(videoMime);
  String? get audioCodec => _codecName(audioMime);

  static String? _codecName(String? mime) {
    if (mime == null) return null;
    final lower = mime.toLowerCase();
    return switch (lower) {
      'video/av01' => 'AV1',
      'video/x-vnd.on2.vp9' => 'VP9',
      'video/x-vnd.on2.vp8' => 'VP8',
      'video/avc' => 'H.264',
      'video/hevc' => 'H.265',
      'video/mp4v-es' => 'MPEG-4',
      'audio/mp4a-latm' => 'AAC',
      'audio/opus' => 'Opus',
      'audio/mpeg' => 'MP3',
      'audio/vorbis' => 'Vorbis',
      'audio/flac' => 'FLAC',
      'audio/ac3' => 'AC-3',
      'audio/eac3' => 'E-AC-3',
      _ => lower.contains('/') ? lower.split('/').last.toUpperCase() : null,
    };
  }
}
