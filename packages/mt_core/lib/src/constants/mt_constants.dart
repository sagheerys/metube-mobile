/// كل الأرقام والقوائم الثابتة للنواة — المصدر: `docs/plan/05-DATA-SCHEMA.md`.
/// لا يُكتب رقم شبكة/تحميل في أي مكان آخر.
abstract final class MTConstants {
  // ── مهلات الشبكة (§1) ──
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// السحب فقط (تدفق الملفات الكبيرة).
  static const Duration downloadReceiveTimeout = Duration(minutes: 30);
  static const Duration testConnectionTimeout = Duration(seconds: 10);

  /// probe سريع لتبديل الروابط (EndpointResolver).
  static const Duration probeTimeout = Duration(seconds: 4);

  /// **سقف حلّ الرابط القصير قبل قرار التوجيه** (بلاغ المالك
  /// 2026-09-08): القرار «قائمة أم مفرد» ينتظر شبكةً، والمستخدم ينتظر
  /// معه — فبعد هذا الحد يُمضى بالرابط كما هو بدل تجميد الواجهة.
  static const Duration routingResolveTimeout = Duration(seconds: 5);

  // ── إيقاع الاستطلاع (§2.3) ──
  static const Duration pollInterval = Duration(seconds: 5);

  /// 120 × 5s = 10 دقائق حد أقصى لخط التحميل.
  static const int maxPollAttempts = 120;

  /// تحديث واجهة Super الحية أثناء وجود نشاط فقط.
  static const Duration livePollInterval = Duration(seconds: 2);

  // ── السحب وإعادة المحاولة (§2.4) ──
  static const int pullRetries = 3;
  static const List<Duration> pullRetryBackoff = [
    Duration(seconds: 3),
    Duration(seconds: 6),
  ];

  // ── الطابور (§3) ──
  static const int maxConcurrentDownloads = 1;

  // ── الجودات (§2.2) ──
  static const List<String> qualityWireValues = [
    'best',
    '1080',
    '720',
    '480',
    'audio',
  ];

  // ── الملفات المحلية (§2.4 + §5.3) ──
  static const String liteFolderName = 'MeTube_Lite';
  static const String superFolderName = 'MeTube_Super';
  static const int filenameTitleMaxLength = 80;
  static const String defaultMediaExtension = 'mp4';

  // ── تصنيف أخطاء المنصات المحظورة (§2.3) ──
  static const List<String> platformBlockedMarkers = [
    'login',
    'sign in',
    'cookie',
    'bot',
  ];

  // ── الروابط القصيرة (§4) ──
  static const int maxRedirectHops = 8;

  /// م-36: المفضلة وسم نظامي مخفي في TagsIndex — يدخل النسخ الاحتياطي
  /// تلقائياً ولا يظهر بين وسوم المستخدم.
  static const String favoritesSystemTag = '__favorites__';

  // ── التحديث الذاتي من GitHub (م-66) ──

  /// `owner/name` لمستودع الإصدارات — **نقطة التبديل الوحيدة**.
  ///
  /// نقطة `releases/latest` تتطلب مستودعاً **عاماً**: ما دام خاصاً يردّ
  /// GitHub 404 ويُعامل كـ«لا تحديث» بصمت (فاشل-آمن). لفصل الإصدارات
  /// عن الكود يكفي تغيير هذا السطر إلى مستودع إصدارات عام مستقل.
  static const String updateRepo = 'sagheerys/metube-mobile';

  /// إيقاع الفحص التلقائي — فحصٌ عند كل إقلاع يُغرق GitHub بلا فائدة،
  /// والإصدارات تصدر بالأسابيع لا بالساعات.
  static const Duration updateCheckInterval = Duration(hours: 12);

  /// اسم ملف التحديث في كاش التطبيق — ثابت كي تدهسه المرة التالية بدل
  /// تكديس ملفات APK قديمة في الجهاز.
  static const String updateApkFileName = 'update.apk';
}
