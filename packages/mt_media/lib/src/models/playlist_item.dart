/// العنصر الموحد لكل المشغلات (صوت/فيديو/ريلز) — **درس Super القديم:**
/// كان في الشاشات صنفان متضاربان لنفس المفهوم فتفرقت أوضاع التشغيل.
/// المفتاح الموحد هو [canonicalUrl] (`05-DATA-SCHEMA.md` §5.5) فيتشارك
/// البثُّ والنسخةُ المحلية نفس موضع الاستئناف (م-19).
class PlaylistItem {
  const PlaylistItem({
    required this.canonicalUrl,
    required this.title,
    this.uploader,
    this.artworkUrl,
    this.localPath,
    this.serverFilename,
    this.isAudio = false,
    this.duration,
    this.aspectRatio,
  });

  /// الرابط المُقنون من `/history` — مفتاح الموضع والوسوم والمفضلة.
  final String canonicalUrl;
  final String title;
  final String? uploader;
  final String? artworkUrl;

  /// مسار النسخة المحلية إن وُجدت — الأولوية في القاعدة الذهبية.
  final String? localPath;

  /// اسم الملف على السيرفر — مصدر البث البديل.
  final String? serverFilename;
  final bool isAudio;

  /// المدة إن عُرفت (من التشغيل السابق أو الفهرس) — لازمة لمسار القِصار.
  final Duration? duration;

  /// نسبة العرض/الارتفاع إن عُرفت — < 1 يعني فيديو عمودي (م-35).
  final double? aspectRatio;

  bool get hasLocal => localPath != null && localPath!.isNotEmpty;
  bool get hasServer => serverFilename != null && serverFilename!.isNotEmpty;
  bool get isPlayable => hasLocal || hasServer;

  /// فيديو عمودي قصير ⇒ يدخل «مسار القِصار» في مشغل الريلز (م-35).
  /// المجهول (لا مدة أو لا نسبة) **ليس** قصيراً — لا تخمين.
  bool get isShortForm =>
      !isAudio &&
      duration != null &&
      duration! <= const Duration(minutes: 3) &&
      aspectRatio != null &&
      aspectRatio! < 1;

  PlaylistItem copyWith({
    String? title,
    String? uploader,
    String? artworkUrl,
    String? localPath,
    String? serverFilename,
    bool? isAudio,
    Duration? duration,
    double? aspectRatio,
  }) =>
      PlaylistItem(
        canonicalUrl: canonicalUrl,
        title: title ?? this.title,
        uploader: uploader ?? this.uploader,
        artworkUrl: artworkUrl ?? this.artworkUrl,
        localPath: localPath ?? this.localPath,
        serverFilename: serverFilename ?? this.serverFilename,
        isAudio: isAudio ?? this.isAudio,
        duration: duration ?? this.duration,
        aspectRatio: aspectRatio ?? this.aspectRatio,
      );

  Map<String, dynamic> toJson() => {
        'url': canonicalUrl,
        'title': title,
        if (uploader != null) 'uploader': uploader,
        if (artworkUrl != null) 'artwork': artworkUrl,
        if (localPath != null) 'localPath': localPath,
        if (serverFilename != null) 'filename': serverFilename,
        'isAudio': isAudio,
        if (duration != null) 'durationMs': duration!.inMilliseconds,
        if (aspectRatio != null) 'aspectRatio': aspectRatio,
      };

  /// تحليل متسامح — العنصر بلا رابط غير صالح فيُهمل أعلى (null).
  static PlaylistItem? fromJson(Map<String, dynamic> json) {
    final url = json['url']?.toString() ?? '';
    if (url.isEmpty) return null;
    final ms = json['durationMs'];
    final ratio = json['aspectRatio'];
    return PlaylistItem(
      canonicalUrl: url,
      title: json['title']?.toString() ?? url,
      uploader: json['uploader']?.toString(),
      artworkUrl: json['artwork']?.toString(),
      localPath: json['localPath']?.toString(),
      serverFilename: json['filename']?.toString(),
      isAudio: json['isAudio'] == true,
      duration: ms is num ? Duration(milliseconds: ms.toInt()) : null,
      aspectRatio: ratio is num ? ratio.toDouble() : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PlaylistItem && other.canonicalUrl == canonicalUrl;

  @override
  int get hashCode => canonicalUrl.hashCode;

  @override
  String toString() => 'PlaylistItem($title)';
}
