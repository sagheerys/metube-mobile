import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart' show MTMediaLocation;

const _audioExtensions = {'mp3', 'm4a', 'aac', 'ogg', 'opus', 'wav', 'flac'};

/// عنصر المكتبة الموحدة (م-13): دمج سجل السيرفر مع الفهرس المحلي
/// بمفتاح canonicalUrl — لكل عنصر شارة مكانه.
class LibraryItem {
  const LibraryItem({
    required this.canonicalUrl,
    required this.title,
    this.uploader,
    this.thumbnail,
    this.serverFilename,
    this.localPath,
    this.timestamp,
    this.sizeBytes,
    this.onServer = false,
    this.isAudio = false,
    this.favorite = false,
    this.tags = const [],
    this.duration,
    this.aspectRatio,
  });

  final String canonicalUrl;
  final String title;
  final String? uploader;
  final String? thumbnail;
  final String? serverFilename;
  final String? localPath;
  final DateTime? timestamp;
  final int? sizeBytes;
  final bool onServer;
  final bool isAudio;
  final bool favorite;
  final List<String> tags;

  /// أبعاد المقطع من `media_shape_index` — تُعرف بعد أول تشغيل (م-35).
  final Duration? duration;
  final double? aspectRatio;

  bool get isOffline => localPath != null;

  /// فيديو عمودي ≤٣ دقائق ⇒ «قِصار» (المجهول ليس قصيراً — لا تخمين).
  bool get isShortForm =>
      !isAudio &&
      duration != null &&
      duration! <= const Duration(minutes: 3) &&
      aspectRatio != null &&
      aspectRatio! < 1;

  MTMediaLocation get location => switch ((isOffline, onServer)) {
        (true, true) => MTMediaLocation.both,
        (true, false) => MTMediaLocation.offline,
        (false, true) => MTMediaLocation.onServer,
        _ => MTMediaLocation.none,
      };

  factory LibraryItem.fromHistory(
    HistoryItem item, {
    String? localPath,
    bool favorite = false,
    List<String> tags = const [],
    Duration? duration,
    double? aspectRatio,
  }) =>
      LibraryItem(
        duration: duration,
        aspectRatio: aspectRatio,
        canonicalUrl: item.canonicalUrl,
        title: item.title ?? item.filename ?? item.canonicalUrl,
        uploader: item.uploader,
        thumbnail: item.thumbnail,
        serverFilename: item.filename,
        localPath: localPath,
        timestamp: item.timestamp,
        sizeBytes: item.sizeBytes,
        onServer: true,
        isAudio: _looksAudio(item.quality, item.format, item.filename),
        favorite: favorite,
        tags: tags,
      );

  /// عنصر محلي لم يعد على السيرفر — بياناته من مساره.
  factory LibraryItem.fromOfflineOnly(
    String canonicalUrl,
    String localPath, {
    bool favorite = false,
    List<String> tags = const [],
    String? cachedThumb,
    Duration? duration,
    double? aspectRatio,
  }) {
    final basename = localPath.split(RegExp(r'[/\\]')).last;
    final dot = basename.lastIndexOf('.');
    return LibraryItem(
      duration: duration,
      aspectRatio: aspectRatio,
      canonicalUrl: canonicalUrl,
      title: dot > 0 ? basename.substring(0, dot) : basename,
      localPath: localPath,
      thumbnail: cachedThumb,
      isAudio: _looksAudio(null, null, basename),
      favorite: favorite,
      tags: tags,
    );
  }

  static bool _looksAudio(String? quality, String? format, String? filename) {
    if (quality == 'audio') return true;
    if (format != null && _audioExtensions.contains(format.toLowerCase())) {
      return true;
    }
    final ext = extensionOf(filename);
    return _audioExtensions.contains(ext);
  }
}

/// مرشحات المكتبة (م-13/م-14): الكل / ♥ المفضلة / دون اتصال / سيرفر.
enum LibraryScope { all, favorites, offline, onServer }

enum MediaTypeFilter { all, video, audio, shorts }

/// خيارات الفرز المحفوظة (video_sort_option §5.1).
enum LibrarySort { newest, oldest, nameAZ, nameZA, largest, smallest }

/// بناء العرض — منطق خالص قابل للاختبار (TRD §3.2).
List<LibraryItem> buildLibraryView(
  List<LibraryItem> items, {
  LibraryScope scope = LibraryScope.all,
  MediaTypeFilter type = MediaTypeFilter.all,
  String query = '',
  String? tag,
  LibrarySort sort = LibrarySort.newest,
}) {
  final q = query.trim().toLowerCase();
  final filtered = items.where((item) {
    final scopeOk = switch (scope) {
      LibraryScope.all => true,
      LibraryScope.favorites => item.favorite,
      LibraryScope.offline => item.isOffline,
      LibraryScope.onServer => item.onServer,
    };
    if (!scopeOk) return false;
    final typeOk = switch (type) {
      MediaTypeFilter.all => true,
      MediaTypeFilter.audio => item.isAudio,
      MediaTypeFilter.video => !item.isAudio,
      // ⚡ قِصار (م-35): العمودية القصيرة المعروفة الأبعاد فقط.
      MediaTypeFilter.shorts => item.isShortForm,
    };
    if (!typeOk) return false;
    if (tag != null && !item.tags.contains(tag)) return false;
    if (q.isNotEmpty && !item.title.toLowerCase().contains(q)) return false;
    return true;
  }).toList();

  int byDate(LibraryItem a, LibraryItem b) =>
      (a.timestamp ?? DateTime(0)).compareTo(b.timestamp ?? DateTime(0));
  int byName(LibraryItem a, LibraryItem b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());
  int bySize(LibraryItem a, LibraryItem b) =>
      (a.sizeBytes ?? 0).compareTo(b.sizeBytes ?? 0);

  filtered.sort(switch (sort) {
    LibrarySort.newest => (a, b) => byDate(b, a),
    LibrarySort.oldest => byDate,
    LibrarySort.nameAZ => byName,
    LibrarySort.nameZA => (a, b) => byName(b, a),
    LibrarySort.largest => (a, b) => bySize(b, a),
    LibrarySort.smallest => bySize,
  });
  return filtered;
}
