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
    final trimmed = _stripBidiMarks(input).trim();
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
  static List<String> extractAllUrls(String input) =>
      _urlPattern.allMatches(_stripBidiMarks(input))
          .map((m) => _stripTrailingPunctuation(m.group(0)!))
          .toList();

  /// علامات الاتجاه والمسافات الصفرية التي **تغلّف بها واتساب وتيليجرام
  /// الروابط داخل الرسائل العربية** (العطل خ-5). بلا حذفها يصل الرابط
  /// إلى yt-dlp بذيل خفي فيفشل بخطأ سيرفر غامض، بينما يعمل الرابط نفسه
  /// عند لصقه يدوياً — وهذا تطبيق عربي أولاً.
  static final RegExp _bidiMarks = RegExp(
    '[\u200B-\u200F\u202A-\u202E\u2066-\u2069\uFEFF]',
  );

  static String _stripBidiMarks(String input) =>
      input.replaceAll(_bidiMarks, '');

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

  /// أطول معرف رقمي ≥10 خانات في المسار **أو الاستعلام** أو '' إن غاب.
  ///
  /// **`=` مع `/` (عطل المالك 2026-09-08):** فيسبوك يضع المعرف في
  /// الاستعلام لا المسار (`m.facebook.com/watch/?v=1619243166301797`)،
  /// فكان يعود فارغاً لكل روابطه — وتسقط المطابقة إلى رتبة التطبيع
  /// التي تمسح الاستعلام فتسوّي كل `facebook.com/watch` ببعضها.
  static String longestNumericId(String url) {
    final matches = RegExp(r'[/=](\d{10,})').allMatches(url);
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
  /// السلّم: حرفي → معرف YouTube → معرف رقمي → تطبيع → بادئة مسار.
  ///
  /// **قاعدة حاسمة (خطأ مُصطاد على السيرفر الحقيقي 2026-09-01):** معرفا
  /// YouTube مرجعان نهائيان — إن وُجدا معاً واختلفا فلا تطابق أبداً، ولا
  /// يُسمح بسقوط روابط watch إلى رتبة التطبيع (التي تمسح الاستعلام فتسوّي
  /// كل `youtube.com/watch` ببعضها — وكاد ذلك يحذف عنصراً بريئاً).
  ///
  /// **وقاعدة ثانية بنفس الثقل (العطل ح-2، 2026-09-02):** الاحتواء الخام
  /// كان يطابق **العنصر الخطأ** لكل ما عدا YouTube:
  /// `soundcloud.com/x/track` كان يطابق `soundcloud.com/x/track-remix`،
  /// ومعرف رقمي يطابق رقماً أطول يبدأ به. النتيجة: سحب ملف بريء باسم
  /// المطلوب، **وحذفه من السيرفر** في Lite. الآن الاحتواء **بحدود**:
  /// الرقم لا يُقبل ملتصقاً برقم آخر، والمسار لا يُقبل إلا بادئةً كاملة
  /// عند فاصل `/` (فيبقى الرابط الخاص `…/track/s-abc123` مطابِقاً).
  static bool urlsMatch(String url1, String url2) {
    if (url1.isEmpty || url2.isEmpty) return false;
    if (url1 == url2) return true;

    final id1 = youtubeVideoId(url1) ?? '';
    final id2 = youtubeVideoId(url2) ?? '';
    if (id1.isNotEmpty && id2.isNotEmpty) return id1 == id2;
    if (id1.isNotEmpty && url2.contains(id1)) return true;
    if (id2.isNotEmpty && url1.contains(id2)) return true;
    // رابط واحد فقط له معرف YouTube والآخر بلا معرف ⇒ لا نكمل لرتب
    // التطبيع المتساهلة (خطر التسوية على مسار watch المشترك).
    if (id1.isNotEmpty || id2.isNotEmpty) return false;

    final numId1 = longestNumericId(url1);
    final numId2 = longestNumericId(url2);
    if (numId1.isNotEmpty && numId2.isNotEmpty) return numId1 == numId2;
    if (numId1.isNotEmpty) return _containsIdAtBoundary(url2, numId1);
    if (numId2.isNotEmpty) return _containsIdAtBoundary(url1, numId2);

    // **استعلامان مختلفان لا يسقطان إلى التطبيع** (عطل المالك
    // 2026-09-08): التطبيع يمسح الاستعلام، ومنصةٌ تحمل الهوية فيه
    // (فيسبوك `?v=…`) تنهار كلها إلى مسار واحد `facebook.com/watch`
    // فيطابق **كل مقطع كلَّ مقطع**. الأثر مقيس: عنصر واحد أُتيح دون
    // اتصال أعطى ملفه لبقية عناصر فيسبوك، ومطابقة `/history` في Lite
    // كانت تسحب ملفاً بريئاً **ثم تحذف الأصل من السيرفر**. وهي نفس
    // القاعدة المكتوبة أعلاه ليوتيوب، مُعمَّمةً على كل منصة.
    final query1 = _queryOf(url1);
    final query2 = _queryOf(url2);
    if (query1.isNotEmpty && query2.isNotEmpty && query1 != query2) {
      return false;
    }

    final norm1 = normalize(url1);
    final norm2 = normalize(url2);
    if (norm1 == norm2) return true;
    return _isPathPrefix(norm1, norm2) || _isPathPrefix(norm2, norm1);
  }

  /// سلسلة الاستعلام وحدها (بلا `#fragment`) — '' إن غابت.
  static String _queryOf(String url) {
    final at = url.indexOf('?');
    if (at < 0) return '';
    final rest = url.substring(at + 1);
    final hash = rest.indexOf('#');
    return (hash < 0 ? rest : rest.substring(0, hash)).toLowerCase();
  }

  /// هل يحوي [url] الرقم [id] **غير ملتصق برقم آخر**؟ (`…/769798712`
  /// ليس `…/76979871`).
  static bool _containsIdAtBoundary(String url, String id) {
    var from = 0;
    while (true) {
      final at = url.indexOf(id, from);
      if (at < 0) return false;
      final before = at == 0 ? '' : url[at - 1];
      final afterIdx = at + id.length;
      final after = afterIdx >= url.length ? '' : url[afterIdx];
      if (!_isDigit(before) && !_isDigit(after)) return true;
      from = at + 1;
    }
  }

  static bool _isDigit(String ch) {
    if (ch.length != 1) return false;
    final code = ch.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  /// [shorter] بادئةُ مسارٍ كاملة لـ [longer] عند فاصل `/` — يقبل
  /// `a/b` مع `a/b/s-token` ويرفض `a/b` مع `a/b-remix`.
  static bool _isPathPrefix(String longer, String shorter) =>
      shorter.isNotEmpty && longer.startsWith('$shorter/');

  /// حارس اجتياز المسار لأسماء الملفات القادمة من السيرفر قبل بناء رابط
  /// `/download/<filename>` — يرفض الفارغ وفواصل المسار والمكوّنين
  /// `.` و`..` وحدهما ومحرف NUL.
  ///
  /// **`..` داخل الاسم ليست اجتيازاً (بلاغ المالك 2026-09-03).** كان
  /// الشرط `contains('..')`، وyt-dlp يقتطع العناوين الطويلة بنقاط —
  /// فكان **كل مقطع طويل العنوان يفشل** بـ«unsafe filename» رغم أن
  /// السيرفر يخدمه. القياس على سيرفر Lite الحقيقي:
  /// `…كهرباء.  مدر... [2077436096300945409].mp4` ⇒ **HTTP 206
  /// video/mp4**. الاجتياز يحتاج فاصل مسار، وهو مرفوض أصلاً.
  static bool isSafeServerFilename(String name) {
    if (name.isEmpty) return false;
    if (name == '.' || name == '..') return false;
    if (name.contains('/') || name.contains('\\')) return false;
    if (name.contains('\u0000')) return false;
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
