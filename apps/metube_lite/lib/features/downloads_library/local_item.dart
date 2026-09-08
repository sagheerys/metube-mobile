import 'package:mt_core/mt_core.dart';

/// مجلد وسائط Lite (§5.3) — يُسجَّل محتواه في MediaStore ليظهر في معرض
/// الهاتف (م-10)، وهو نفس مسار Lite القديم فتبقى مساراته المحفوظة صالحة.
const liteMediaDir = '/storage/emulated/0/Download/MeTube_Lite';

const _audioExtensions = {'mp3', 'm4a', 'aac', 'ogg', 'opus', 'wav', 'flac'};
const _videoExtensions = {'mp4', 'webm', 'mkv', 'mov', 'avi', '3gp', 'm4v'};

/// امتدادات الوسائط التي تُعرض في المكتبة المحلية (م-12).
bool isMediaFile(String path) {
  final ext = extensionOf(path);
  return _audioExtensions.contains(ext) || _videoExtensions.contains(ext);
}

/// عنصر المكتبة المحلية (م-12): **الملف على القرص هو الحقيقة** — بقية
/// الحقول إثراء من الفهارس.
///
/// **مفتاح العنصر [key]:** canonicalUrl إن عُرف (كل ما ينزّله Lite v2
/// يعرف رابطه)، وإلا **المسار المطلق**. هذا ما يجعل بيانات Lite القديم
/// تعمل كما هي: مواضع الاستئناف والقوائم والعناوين هناك كلها مفاتيحها
/// مسارات ملفات (مُثبت على نسخة المالك: 32 موضعاً و18 مدخل قائمة).
class LocalItem {
  const LocalItem({
    required this.key,
    required this.path,
    required this.title,
    required this.sizeBytes,
    required this.modified,
    this.canonicalUrl,
    this.thumbnail,
    this.favorite = false,
    this.duration,
    this.aspectRatio,
  });

  final String key;
  final String path;
  final String title;
  final int sizeBytes;
  final DateTime modified;

  /// null = ملف لا نعرف رابطه (مهاجر من Lite القديم أو نُسخ يدوياً).
  final String? canonicalUrl;
  final String? thumbnail;
  final bool favorite;

  /// أبعاد المقطع من `media_shape_index` — تُعرف بعد أول تشغيل (م-35).
  final Duration? duration;
  final double? aspectRatio;

  String get filename => path.split(RegExp(r'[/\\]')).last;

  bool get isAudio => _audioExtensions.contains(extensionOf(path));

  MediaPlatform get platform =>
      canonicalUrl == null ? MediaPlatform.other : MediaPlatform.detect(canonicalUrl!);

  /// فيديو عمودي ≤٣ دقائق ⇒ «قِصار» (المجهول ليس قصيراً — لا تخمين).
  bool get isShortForm =>
      !isAudio &&
      duration != null &&
      duration! <= const Duration(minutes: 3) &&
      aspectRatio != null &&
      aspectRatio! < 1;

  /// العنوان الافتراضي حين لا يوجد في فهرس العناوين: اسم الملف بلا
  /// الامتداد وبلا بصمة الوقت `_HHmmss` التي يضيفها بناء الاسم (§2.4).
  static String titleFromFilename(String filename) {
    final dot = filename.lastIndexOf('.');
    final stem = dot > 0 ? filename.substring(0, dot) : filename;
    return stem.replaceFirst(RegExp(r'_\d{6}$'), '');
  }
}

/// مرشح النطاق في Lite: لا «دون اتصال/سيرفر» — كل شيء محلي (م-14).
enum LocalScope { all, favorites }

enum MediaTypeFilter { all, video, audio, shorts }

/// **أوضاع العرض الأربعة — اختيار واحد حصري لا أعلام متداخلة.**
///
/// كانا علمين (`compact` و`grid`) يمكن تشغيلهما معاً بلا معنى، والوضع
/// الرابع (البطاقات) كان سيجعلها ثلاثة أعلام بثماني حالات نصفها
/// مستحيل. القيمة الواحدة تُلغي الحالة المستحيلة من أصلها.
enum LibraryViewMode {
  /// صفٌّ بمصغرة جانبية — الافتراضي، الأنسب للعناوين الطويلة والصوت.
  list,

  /// نفس الصف بمصغرة أصغر وسطر عنوان واحد — أكثر عناصر في الشاشة.
  compact,

  /// عمودان بغلاف 16:9 — مسح بصري سريع.
  grid,

  /// **عمود واحد بغلاف عريض** (طلب المالك 2026-09-08، نمط يوتيوب):
  /// أكبر غلاف ممكن لأقل عدد عناصر — للتصفح المتأني لا للبحث.
  cards,
}

/// خيارات الفرز المحفوظة (`video_sort_option` §5.1).
enum LibrarySort { newest, oldest, nameAZ, nameZA, largest, smallest }

/// بناء العرض — منطق خالص قابل للاختبار (TRD §3.2).
List<LocalItem> buildLocalLibraryView(
  List<LocalItem> items, {
  LocalScope scope = LocalScope.all,
  MediaTypeFilter type = MediaTypeFilter.all,
  String query = '',
  MediaPlatform? platform,
  LibrarySort sort = LibrarySort.newest,
}) {
  final q = query.trim().toLowerCase();
  final filtered = items.where((item) {
    if (scope == LocalScope.favorites && !item.favorite) return false;
    final typeOk = switch (type) {
      MediaTypeFilter.all => true,
      MediaTypeFilter.audio => item.isAudio,
      MediaTypeFilter.video => !item.isAudio,
      // ⚡ قِصار (م-35): العمودية القصيرة المعروفة الأبعاد فقط.
      MediaTypeFilter.shorts => item.isShortForm,
    };
    if (!typeOk) return false;
    if (platform != null && item.platform != platform) return false;
    if (q.isNotEmpty && !item.title.toLowerCase().contains(q)) return false;
    return true;
  }).toList();

  int byDate(LocalItem a, LocalItem b) => a.modified.compareTo(b.modified);
  int byName(LocalItem a, LocalItem b) =>
      a.title.toLowerCase().compareTo(b.title.toLowerCase());
  int bySize(LocalItem a, LocalItem b) =>
      a.sizeBytes.compareTo(b.sizeBytes);

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

/// عدّادات المنصات الحية لرقائق المرشح (م-14 — Lite) بترتيب الأكثر أولاً.
/// المنصة المجهولة (`other`) تُدرج أخيراً كي لا تتصدر القائمة.
List<MapEntry<MediaPlatform, int>> platformCounts(List<LocalItem> items) {
  final counts = <MediaPlatform, int>{};
  for (final item in items) {
    counts[item.platform] = (counts[item.platform] ?? 0) + 1;
  }
  final entries = counts.entries.toList()
    ..sort((a, b) {
      if ((a.key == MediaPlatform.other) != (b.key == MediaPlatform.other)) {
        return a.key == MediaPlatform.other ? 1 : -1;
      }
      return b.value.compareTo(a.value);
    });
  return entries;
}
