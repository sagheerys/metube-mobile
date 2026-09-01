import '../constants/mt_constants.dart';

/// أدوات الروابط الخالصة (بلا شبكة): استخراج من نص المشاركة، معرفات
/// YouTube/الأرقام، التطبيع، المطابقة الضبابية، وحارس اسم ملف السيرفر.
/// المرجع: م-4 في PRD + `05-DATA-SCHEMA.md` §2.3.
abstract final class UrlKit {
  static final RegExp _urlPattern = RegExp(
    r'https?://[^\s<>"]+',
    caseSensitive: false,
  );

  /// معرف YouTube (11 محرفاً): watch / embed / v / shorts / live / youtu.be.
  static final RegExp _youtubeIdPattern = RegExp(
    r'(?:youtu\.be/|youtube\.com/(?:watch\?v=|embed/|v/|shorts/|live/))'
    r'([a-zA-Z0-9_-]{11})',
  );
  static final RegExp _youtubeQueryIdPattern = RegExp(
    r'[?&]v=([a-zA-Z0-9_-]{11})',
  );

  /// تجريد الرابط من نص المشاركة الملفوف حوله (مشاركة SoundCloud مثلاً
  /// جملة كاملة + الرابط). يعيد المدخل نفسه إن لم يوجد رابط ليكشفه التحقق.
  static String extractUrl(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return trimmed;
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('http://') || lower.startsWith('https://')) {
      final spaceIdx = trimmed.indexOf(RegExp(r'\s'));
      return _stripTrailingPunctuation(
        spaceIdx < 0 ? trimmed : trimmed.substring(0, spaceIdx),
      );
    }
    final match = _urlPattern.firstMatch(trimmed);
    return match == null ? trimmed : _stripTrailingPunctuation(match.group(0)!);
  }

  /// كل الروابط في نص (مشاركة عدة روابط دفعة واحدة — م-3).
  static List<String> extractAllUrls(String input) => _urlPattern
      .allMatches(input)
      .map((m) => _stripTrailingPunctuation(m.group(0)!))
      .toList();

  /// تنظيف الترقيم الزائد الذي تلصقه تطبيقات المراسلة بنهاية الرابط.
  static String _stripTrailingPunctuation(String url) =>
      url.replaceFirst(RegExp(r'''[)\]}>.,;:!?'"،؛]+$'''), '');

  /// معرف فيديو YouTube أو null لغير YouTube.
  static String? youtubeVideoId(String url) {
    final byPath = _youtubeIdPattern.firstMatch(url)?.group(1);
    if (byPath != null) return byPath;
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      return _youtubeQueryIdPattern.firstMatch(url)?.group(1);
    }
    return null;
  }

  /// أطول معرف رقمي ≥10 خانات في المسار (FB/IG/TikTok) أو '' إن غاب.
  static String longestNumericId(String url) {
    final matches = RegExp(r'/(\d{10,})').allMatches(url);
    if (matches.isEmpty) return '';
    return matches
        .map((m) => m.group(1)!)
        .reduce((a, b) => a.length >= b.length ? a : b);
  }

  /// تطبيع للمطابقة: إزالة scheme و`www./m./on.` والاستعلام والشرطة الأخيرة.
  static String normalize(String url) {
    var u = url.trim().toLowerCase();
    u = u.replaceFirst(RegExp(r'^https?://'), '');
    u = u.replaceFirst(RegExp(r'^(www\.|m\.|on\.)'), '');
    u = u.replaceFirst(RegExp(r'[?#].*$'), '');
    u = u.replaceFirst(RegExp(r'/+$'), '');
    return u;
  }

  /// المطابقة الضبابية بين الرابط المُدخل ورابط `/history` المُقنون —
  /// السلّم: حرفي → معرف YouTube → معرف رقمي → تطبيع → احتواء.
  static bool urlsMatch(String url1, String url2) {
    if (url1.isEmpty || url2.isEmpty) return false;
    if (url1 == url2) return true;

    final id1 = youtubeVideoId(url1) ?? '';
    final id2 = youtubeVideoId(url2) ?? '';
    if (id1.isNotEmpty && id2.isNotEmpty && id1 == id2) return true;
    if (id1.isNotEmpty && url2.contains(id1)) return true;
    if (id2.isNotEmpty && url1.contains(id2)) return true;

    final numId1 = longestNumericId(url1);
    final numId2 = longestNumericId(url2);
    if (numId1.isNotEmpty && numId2.isNotEmpty && numId1 == numId2) return true;
    if (numId1.isNotEmpty && url2.contains(numId1)) return true;
    if (numId2.isNotEmpty && url1.contains(numId2)) return true;

    final norm1 = normalize(url1);
    final norm2 = normalize(url2);
    if (norm1 == norm2) return true;
    if (norm1.contains(norm2) || norm2.contains(norm1)) return true;

    return false;
  }

  /// حارس اجتياز المسار لأسماء الملفات القادمة من السيرفر قبل بناء رابط
  /// `/download/<filename>` — يرفض الفارغ و`..` و`/` و`\`.
  static bool isSafeServerFilename(String name) {
    if (name.isEmpty) return false;
    if (name.contains('..')) return false;
    if (name.contains('/') || name.contains('\\')) return false;
    return true;
  }

  /// هل الرابط قصير يحتاج حلاً بتتبع redirect؟ (`05-DATA-SCHEMA.md` §4).
  static bool needsResolution(String url) {
    final u = url.toLowerCase();
    return u.contains('vt.tiktok.com') ||
        u.contains('vm.tiktok.com') ||
        u.contains('fb.watch') ||
        (u.contains('facebook.com') && u.contains('/share/')) ||
        u.contains('on.soundcloud.com');
  }

  /// هل نصّ خطأ السيرفر يدل على حظر منصة (كوكيز)؟
  static bool isPlatformBlockedError(String error) {
    final e = error.toLowerCase();
    return MTConstants.platformBlockedMarkers.any(e.contains);
  }
}
