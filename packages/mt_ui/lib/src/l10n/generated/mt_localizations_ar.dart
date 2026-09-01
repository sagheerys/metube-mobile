// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'mt_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class MTLocalizationsAr extends MTLocalizations {
  MTLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get about => 'حول';

  @override
  String get aboutApp => 'حول التطبيق';

  @override
  String get activeDownloads => 'التحميلات النشطة';

  @override
  String get activeDownloadsSheet => 'التحميلات الجارية';

  @override
  String get activeNow => 'نشط الآن';

  @override
  String get addEndpoint => 'أضف نقطة نهاية';

  @override
  String get addLinkFab => 'إضافة رابط';

  @override
  String addNToServer(int count) {
    return 'إضافة $count إلى الخادم';
  }

  @override
  String get addToPlaylist => 'إضافة إلى قائمة';

  @override
  String get addUrl => 'إضافة رابط';

  @override
  String addedNToServer(int count) {
    return 'أُضيف $count إلى الخادم';
  }

  @override
  String get addedToFavorites => 'أُضيف إلى المفضلة';

  @override
  String get addedToQueue => 'أُضيف إلى قائمة التنزيل';

  @override
  String get allDownloadsFinished => 'اكتملت جميع التحميلات!';

  @override
  String get allPlatforms => 'كل المنصات';

  @override
  String get allRightsReserved => 'جميع الحقوق محفوظة';

  @override
  String get allTagsFilter => 'الكل';

  @override
  String get appFeatures => 'مميزات التطبيق';

  @override
  String get appTitle => 'MeTube Super';

  @override
  String get appearance => 'المظهر';

  @override
  String get audioOnly => 'صوت فقط';

  @override
  String get authHelper => 'اتركه فارغاً للخوادم المفتوحة (بلا كلمة مرور)';

  @override
  String get authentication => 'المصادقة (اختياري)';

  @override
  String get autoBackgroundAudio => 'تشغيل تلقائي في الخلفية';

  @override
  String get autoPlayNext => 'التشغيل التلقائي: مفعل';

  @override
  String get autoPlayOff => 'التشغيل التلقائي: متوقف';

  @override
  String get autoRestoreSuccess =>
      'تمت استعادة البيانات من النسخة الاحتياطية بنجاح!';

  @override
  String get autoUrlSwitching => 'تبديل URL تلقائي';

  @override
  String get availability => 'التوفّر';

  @override
  String get availabilityOffline => 'بلا اتصال (نسخة محلية)';

  @override
  String get availabilityServer => 'الخادم (بث)';

  @override
  String get backgroundDownload => 'جاري تحميل الملفات في الخلفية...';

  @override
  String get backgroundPlay => 'تشغيل بالخلفية';

  @override
  String get backupFailed => 'فشل النسخ الاحتياطي';

  @override
  String get backupNow => 'انسخ الآن';

  @override
  String get backupNowSubtitle => 'حفظ نسخة احتياطية مشفّرة في مجلد التنزيلات';

  @override
  String get backupOrphaned => 'ملف النسخة الاحتياطية غير قابل للقراءة';

  @override
  String get backupReset => 'تم حذف الـ backup القديم';

  @override
  String get backupRestore => 'النسخ الاحتياطي والاستعادة';

  @override
  String get backupSettings => 'نسخ جميع البيانات احتياطيا';

  @override
  String backupSuccess(Object path) {
    return 'حُفظت النسخة في: $path';
  }

  @override
  String get cancel => 'إلغاء';

  @override
  String get cardView => 'عرض البطاقات';

  @override
  String get clear => 'مسح';

  @override
  String get clearAllSettings => 'مسح كل الإعدادات';

  @override
  String get clearLogs => 'مسح السجلّات';

  @override
  String get clearLogsConfirm => 'حذف كل سجلّات التشخيص؟';

  @override
  String get clipboardEmpty => 'الحافظة فارغة';

  @override
  String get clipboardLinkReady => 'لصق الرابط';

  @override
  String get closePlayer => 'إغلاق المشغل';

  @override
  String get compactView => 'عرض مدمج';

  @override
  String get completed => 'مكتمل';

  @override
  String get connecting => 'جارٍ الاتصال...';

  @override
  String get connectionFailed => 'فشل الاتصال';

  @override
  String get contactDeveloper => 'تواصل مع المطور';

  @override
  String get copiedToClipboard => 'نُسِخ إلى الحافظة';

  @override
  String get create => 'إنشاء';

  @override
  String get createPlaylist => 'إنشاء قائمة';

  @override
  String get creator => 'المنشئ';

  @override
  String get currentServerAddress => 'عنوان الخادم الحالي';

  @override
  String get date => 'التاريخ';

  @override
  String get defaultQuality => 'جودة الفيديو الافتراضية';

  @override
  String get delete => 'حذف';

  @override
  String get deleteFromServer => 'حذف من الخادم';

  @override
  String get deleteFromServerConfirm => 'إزالة هذا العنصر من الخادم؟';

  @override
  String deleteMultipleConfirm(int count) {
    return 'حذف $count فيديو؟\n\nسيتم ازالة الملفات من جهازك.';
  }

  @override
  String deletePlaylistConfirm(Object name) {
    return 'حذف \\\"$name\\\"؟';
  }

  @override
  String get deleteSelected => 'حذف المحدد';

  @override
  String get deleteTag => 'حذف الوسم';

  @override
  String deleteTagConfirm(Object tag) {
    return 'حذف الوسم \\\"$tag\\\" من كل العناصر؟ لن تُحذف الفيديوهات نفسها.';
  }

  @override
  String get deleteVideo => 'حذف الفيديو';

  @override
  String deleteVideoConfirm(Object title) {
    return 'حذف \\\"$title\\\"؟\n\nسيؤدي هذا إلى إزالة الملف من جهازك.';
  }

  @override
  String deletedTitle(Object title) {
    return 'تم الحذف: $title';
  }

  @override
  String get deselectAll => 'إلغاء التحديد';

  @override
  String get detailTitle => 'العنوان';

  @override
  String get details => 'التفاصيل';

  @override
  String get developer => 'المطور';

  @override
  String get developerName => 'ياسر صغير';

  @override
  String get diagnosticLogs => 'سجلّات التشخيص';

  @override
  String get diagnostics => 'التشخيص';

  @override
  String get disclaimer => 'اخلاء مسؤولية';

  @override
  String get dismiss => 'تجاهل';

  @override
  String get done => 'تم';

  @override
  String get download => 'تنزيل';

  @override
  String get downloadAndShare => 'تنزيل ومشاركة';

  @override
  String get downloadComplete => 'اكتمل التحميل';

  @override
  String get downloadCompleteTitle => 'اكتمل!';

  @override
  String get downloadDate => 'تاريخ التحميل';

  @override
  String get downloadFailed => 'فشل التحميل';

  @override
  String get downloadFailedStatus => 'فشل التنزيل';

  @override
  String get downloadFailedTitle => 'فشل التنزيل';

  @override
  String get downloadQuality => 'جودة التنزيل';

  @override
  String get downloadStarted => 'بدأ التحميل...';

  @override
  String downloadTracks(int count) {
    return 'تحميل $count مقطع';
  }

  @override
  String get downloadUrlUnavailable => 'رابط التنزيل غير متاح';

  @override
  String get downloading => 'جاري التحميل...';

  @override
  String downloadingSize(Object received, Object total) {
    return 'جارٍ التنزيل… $received / $total م.ب';
  }

  @override
  String get downloadingTitle => 'جارٍ التنزيل';

  @override
  String get downloadsTab => 'التحميلات';

  @override
  String get email => 'البريد الالكتروني';

  @override
  String get emptyLibraryMessage => 'أضِف رابط فيديو، أو اسحب للتحديث.';

  @override
  String get emptyPlaylist => 'قائمة فارغة';

  @override
  String get emptyPlaylistMessage => 'أضِف فيديوهات من المكتبة';

  @override
  String get endpointReachable => 'يمكن الوصول';

  @override
  String get endpointUnreachable => 'تعذّر الوصول';

  @override
  String get endpointUrl => 'عنوان نقطة النهاية';

  @override
  String get enterUrl => 'ادخل الرابط';

  @override
  String get enterUrlHint => 'الصق رابط الفيديو هنا...';

  @override
  String get enterUrlPrompt => 'أدخل رابط فيديو لتنزيله:';

  @override
  String errorGeneric(Object message) {
    return 'خطأ: $message';
  }

  @override
  String get errorLogs => 'سجل الاخطاء';

  @override
  String get errorLogsSubtitle => 'عرض سجلات التطبيق للتشخيص';

  @override
  String get exportBackupKey => 'تصدير مفتاح النسخ الاحتياطي';

  @override
  String get exportKeyTitle => 'تصدير مفتاح النسخ';

  @override
  String get externalNetworkSection => 'شبكة خارجية';

  @override
  String get failed => 'فشل';

  @override
  String get failedToLoadPlaylist => 'فشل تحميل القائمة';

  @override
  String get failedToLoadVideo => 'فشل تحميل الفيديو';

  @override
  String get failedToQueue => 'فشلت الإضافة إلى القائمة';

  @override
  String get favorites => 'المفضلة';

  @override
  String get featureBackup => 'نسخ احتياطي واستعادة تلقائية';

  @override
  String get featureBilingual => 'دعم اللغة العربية والانجليزية';

  @override
  String get featureDownload => 'تحميل فيديوهات من يوتيوب ومنصات اخرى';

  @override
  String get featurePlayer => 'تحميل مباشر عبر مشاركة الروابط من أي تطبيق';

  @override
  String get featurePlaylists => 'انشاء وادارة قوائم التشغيل';

  @override
  String get featureThemes => 'وضع داكن وفاتح';

  @override
  String get fieldHelp => 'مساعدة';

  @override
  String get file => 'الملف';

  @override
  String get fileName => 'اسم الملف';

  @override
  String get fileNotFound => 'الملف غير موجود';

  @override
  String get fileSize => 'حجم الملف';

  @override
  String fileSizeBytes(Object value) {
    return '$value بايت';
  }

  @override
  String fileSizeGB(Object value) {
    return '$value ج.ب';
  }

  @override
  String fileSizeKB(Object value) {
    return '$value ك.ب';
  }

  @override
  String fileSizeMB(Object value) {
    return '$value م.ب';
  }

  @override
  String get filterAll => 'الكل';

  @override
  String get filterAudio => 'صوت';

  @override
  String get filterOffline => 'بلا اتصال';

  @override
  String get filterPlaylists => 'قوائم';

  @override
  String get filterServer => 'الخادم';

  @override
  String get filterVideo => 'فيديو';

  @override
  String get format => 'الصيغة';

  @override
  String get helpAboutField => 'حول هذا الحقل';

  @override
  String get howItWorks => 'كيف يعمل';

  @override
  String get importBackupKey => 'استيراد مفتاح النسخ الاحتياطي';

  @override
  String get importKeySubtitle => 'حمّل مفتاحاً صُدِّر سابقاً قبل الاستعادة';

  @override
  String get importKeyTitle => 'استيراد مفتاح النسخ';

  @override
  String get keyExportFailed => 'فشل تصدير مفتاح النسخ الاحتياطي';

  @override
  String keyExported(Object path) {
    return 'حُفظ المفتاح في:\n$path\n\nاحفظه في مكان آمن (مثل Google Drive).';
  }

  @override
  String keyExportedMessage(Object path) {
    return 'تم الحفظ في:\n$path\n\nارفع هذا الملف إلى قوقل درايف (أو مكان آمن آخر). ستحتاجه لاستعادة نسختك الاحتياطية بعد مسح البيانات أو على هاتف جديد.';
  }

  @override
  String get keyExportedTitle => 'تم حفظ مفتاح النسخ الاحتياطي';

  @override
  String get keyImportConfirm => 'استبدال المفتاح';

  @override
  String get keyImportConfirmTitle => 'استبدال المفتاح الحالي؟';

  @override
  String get keyImportInvalid => 'ملف مفتاح غير صالح';

  @override
  String get keyImported => 'تم استيراد المفتاح. يمكنك الآن استخدام الاستعادة.';

  @override
  String get keyImportedTitle => 'تم استيراد المفتاح';

  @override
  String get language => 'اللغة';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get latestAdditions => 'أحدث الإضافات';

  @override
  String get licenses => 'تراخيص المصادر المفتوحة';

  @override
  String get loadingVideo => 'جارٍ تحميل الفيديو...';

  @override
  String get localNetworkSection => 'شبكة محلية';

  @override
  String get localUrlLabel => 'عنوان الخادم المحلي';

  @override
  String localVideos(int count) {
    return 'المكتبة ($count)';
  }

  @override
  String get madeWithLove => 'صنع بـ ❤️ بواسطة ياسر صغير';

  @override
  String get makeAvailableOffline => 'إتاحة بلا اتصال';

  @override
  String get manageTags => 'إدارة الوسوم';

  @override
  String get modeAuto => 'تلقائي';

  @override
  String get modeAutoNext => 'تلقائي';

  @override
  String get modeOff => 'إيقاف';

  @override
  String get modeRepeat => 'تكرار';

  @override
  String get modeRepeatAll => 'تكرار الكل';

  @override
  String get modeRepeatOne => 'تكرار الحالي';

  @override
  String get navLibrary => 'المكتبة';

  @override
  String get navMyDownloads => 'تحميلاتي';

  @override
  String get navPlaylists => 'القوائم';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get networkSettings => 'الشبكات';

  @override
  String get newTagHint => 'وسم جديد';

  @override
  String get next => 'التالي';

  @override
  String get noDownloads => 'لا توجد تحميلات';

  @override
  String get noLogsFound => 'لا توجد سجلّات';

  @override
  String get noPlaylists => 'لا توجد قوائم';

  @override
  String get noPlaylistsMessage => 'أنشئ قائمة لتنظيم فيديوهاتك';

  @override
  String get noResults => 'لا نتائج';

  @override
  String get noResultsMessage => 'لا توجد عناصر مطابقة لبحثك.';

  @override
  String get noTagsYet => 'لا وسوم بعد. أنشئ واحداً بالأسفل.';

  @override
  String get noValidUrl => 'لم يُعثر على رابط فيديو صالح';

  @override
  String get noVideosFound => 'مكتبتك فارغة';

  @override
  String get nothingHereYet => 'لا يوجد شيء بعد';

  @override
  String get nowPlaying => 'قيد التشغيل';

  @override
  String get offlineSmartList => 'دون اتصال';

  @override
  String get ok => 'حسناً';

  @override
  String get openGithub => 'فتح MeTube على GitHub';

  @override
  String get openOriginalLink => 'فتح الرابط الأصلي';

  @override
  String get originalUrl => 'الرابط الأصلي';

  @override
  String get password => 'كلمة المرور';

  @override
  String get passwordRequired => 'كلمة المرور مطلوبة';

  @override
  String get pasteFromClipboard => 'لصق';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get pinPlaylist => 'تثبيت في الصدارة';

  @override
  String get platform => 'المنصّة';

  @override
  String platformCount(Object name, int count) {
    return '$name · $count';
  }

  @override
  String get platformFilter => 'المنصة';

  @override
  String get play => 'تشغيل';

  @override
  String get playAllFavorites => 'شغّل المفضلة كلها';

  @override
  String get playbackError => 'خطأ في التشغيل';

  @override
  String get playbackSpeed => 'سرعة التشغيل';

  @override
  String get playerError => 'تعذّر تشغيل هذا الملف';

  @override
  String get playerLoading => 'جارٍ تحميل الفيديو...';

  @override
  String get playlist => 'قائمة التشغيل';

  @override
  String get playlistDeleted => 'حُذفت القائمة';

  @override
  String get playlistDetails => 'تفاصيل القائمة';

  @override
  String get playlistName => 'اسم القائمة';

  @override
  String get playlistNameHint => 'قائمتي';

  @override
  String playlistOf(int current, int total) {
    return '$current / $total';
  }

  @override
  String get playlists => 'قوائم التشغيل';

  @override
  String playlistsCount(int count) {
    return '$count قائمة';
  }

  @override
  String get pleaseEnterUrl => 'الرجاء إدخال رابط';

  @override
  String get preparingDownload => 'جارٍ تجهيز التنزيل...';

  @override
  String get previous => 'السابق';

  @override
  String get quality => 'الجودة';

  @override
  String get quality1080 => '1080p';

  @override
  String get quality480 => '480p';

  @override
  String get quality720 => '720p';

  @override
  String get qualityAudio => 'صوت فقط';

  @override
  String get qualityBest => 'أفضل جودة متاحة';

  @override
  String get qualityHelper => 'تُرسَل إلى الخادم لعمليات التنزيل الجديدة';

  @override
  String queuePosition(int position) {
    return 'الموقع في الطابور: $position';
  }

  @override
  String get queued => 'في الانتظار';

  @override
  String get readyToShare => 'جاهز للمشاركة!';

  @override
  String get reelsEndBack => 'عودة للمكتبة';

  @override
  String get reelsEndReplay => 'أعد من البداية';

  @override
  String get reelsEndTitle => 'انتهى مسار القِصار';

  @override
  String get refresh => 'تحديث';

  @override
  String get remove => 'إزالة';

  @override
  String get removeFromPlaylist => 'إزالة من القائمة';

  @override
  String get removeOfflineCopy => 'إزالة النسخة المحلية';

  @override
  String get removeOfflineTitle => 'إزالة النسخة المحلية';

  @override
  String get removedFromFavorites => 'أُزيل من المفضلة';

  @override
  String get rename => 'إعادة تسمية';

  @override
  String get renameTag => 'إعادة تسمية الوسم';

  @override
  String get reorderHint => 'اسحب لإعادة الترتيب';

  @override
  String get reportBug => 'الابلاغ عن مشكلة';

  @override
  String get resetBackup => 'حذف وبدء من جديد';

  @override
  String get restoreCancelled => 'لم يُعثر على ملف النسخة في مجلد التنزيلات';

  @override
  String get restoreData => 'استعادة';

  @override
  String get restoreFailed => 'فشلت الاستعادة — ملف نسخة غير صالح';

  @override
  String get restoreNotFound => 'لا يوجد ملف نسخة في Downloads/MeTube_Super';

  @override
  String get restoreSettings => 'استعادة جميع البيانات';

  @override
  String get restoreSuccess => 'تمت استعادة البيانات بنجاح';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String retryingAttempt(int attempt, int max) {
    return 'إعادة المحاولة $attempt/$max…';
  }

  @override
  String get saveQueueAsPlaylist => 'احفظ هذه القائمة كبلاي لست';

  @override
  String get saveSettings => 'حفظ الإعدادات';

  @override
  String get savedPartial => 'تم الحفظ (فشل الحذف من السيرفر)';

  @override
  String get savedSuccess => 'تم حفظ الإعدادات';

  @override
  String get savedTo => 'تم الحفظ في Downloads/MeTube_Lite';

  @override
  String get savedToDownloads => 'حُفِظ في Downloads/MeTube_Super';

  @override
  String get scanningVideos => 'جاري فحص الفيديوهات...';

  @override
  String get searchHint => 'بحث…';

  @override
  String get searchLogs => 'بحث في السجلّات…';

  @override
  String searchResults(int found, int total) {
    return 'النتائج: $found من $total';
  }

  @override
  String get searchVideos => 'بحث في الفيديوهات...';

  @override
  String get selectAll => 'تحديد الكل';

  @override
  String selected(int count) {
    return '$count محدد';
  }

  @override
  String selectedCount(int count) {
    return '$count محدد';
  }

  @override
  String get serverConfiguration => 'إعداد الخادم';

  @override
  String get serverDownload => 'تنزيل عبر الخادم';

  @override
  String get serverStatusChecking => 'جارٍ فحص الاتصال…';

  @override
  String get serverStatusConnected => 'متصل بالخادم';

  @override
  String get serverStatusOffline => 'تعذّر الوصول للخادم';

  @override
  String get serverStatusUnconfigured => 'لم يُضبط الخادم';

  @override
  String get serverUrl => 'رابط السيرفر (MeTube)';

  @override
  String get serverUrlHelpTitle => 'حول رابط السيرفر';

  @override
  String get serverUrlHint => 'http://192.168.1.5:8086 أو https://domain.com';

  @override
  String get serverUrlLabel => 'رابط الخادم (MeTube Super)';

  @override
  String get serverUrlRequired => 'رابط الخادم مطلوب';

  @override
  String get settings => 'الإعدادات';

  @override
  String get settingsCleared => 'تم مسح الإعدادات';

  @override
  String get settingsSaved => 'تم حفظ الإعدادات بنجاح';

  @override
  String get share => 'مشاركة';

  @override
  String shareFailed(Object message) {
    return 'فشلت المشاركة: $message';
  }

  @override
  String get shareKeyFile => 'مشاركة ملف المفتاح';

  @override
  String get shareLogs => 'مشاركة السجلات';

  @override
  String get shareRedacted => 'مشاركة (مُنقّحة)';

  @override
  String get shareSelected => 'مشاركة المحدد';

  @override
  String get shareVia => 'مشاركة';

  @override
  String get shuffle => 'تبديل عشوائي';

  @override
  String get size => 'الحجم';

  @override
  String get smartPlaylists => 'قوائم ذكية';

  @override
  String get sortBy => 'ترتيب حسب';

  @override
  String get sortLargest => 'الأكبر حجماً';

  @override
  String get sortNameAZ => 'الاسم أ–ي';

  @override
  String get sortNameZA => 'الاسم ي–أ';

  @override
  String get sortNewest => 'الأحدث';

  @override
  String get sortOldest => 'الأقدم';

  @override
  String get sortSmallest => 'الأصغر حجماً';

  @override
  String get source => 'المصدر';

  @override
  String get sourceCode => 'الكود المصدري';

  @override
  String get speedNormal => 'عادي';

  @override
  String get startingDownload => 'جاري بدء التحميل عبر السيرفر...';

  @override
  String get status => 'الحالة';

  @override
  String get statusCompleted => 'اكتمل';

  @override
  String get statusDownloading => 'جارٍ التنزيل...';

  @override
  String get statusError => 'خطأ';

  @override
  String get statusOffline => 'بلا اتصال';

  @override
  String get statusQueued => 'في القائمة';

  @override
  String get statusQueuing => 'جارٍ الإضافة إلى القائمة...';

  @override
  String get statusServerDownloading => 'الخادم يُنزّل...';

  @override
  String get statusStream => 'بث';

  @override
  String get statusWaiting => 'في الانتظار...';

  @override
  String get streamUrlUnavailable => 'رابط البث غير متاح';

  @override
  String get tagActionsHint => 'اضغط مطوّلاً على وسم لإعادة تسميته أو حذفه.';

  @override
  String get tagAudio => 'صوت';

  @override
  String get tagVideo => 'فيديو';

  @override
  String get tags => 'الوسوم';

  @override
  String get tapToCopy => 'اضغط للنسخ';

  @override
  String get theme => 'السمة';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeDarkMode => 'السمة الداكنة';

  @override
  String get themeFollowSystem => 'اتّباع إعدادات النظام';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeLightMode => 'السمة الفاتحة';

  @override
  String get themeSystem => 'النظام';

  @override
  String totalDuration(Object duration) {
    return 'الإجمالي: $duration';
  }

  @override
  String tracksCount(int count) {
    return '$count مقطع';
  }

  @override
  String get tryAgain => 'حاول مرة أخرى';

  @override
  String get undo => 'تراجع';

  @override
  String get unpinPlaylist => 'إلغاء التثبيت';

  @override
  String get upNext => 'التالي';

  @override
  String get urlMustStartWith => 'يجب أن يبدأ الرابط بـ http:// أو https://';

  @override
  String get urlRequiredField => 'أدخل عنواناً';

  @override
  String get useCurrentConnection => 'استخدم الاتصال الحالي';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get usernameRequired => 'اسم المستخدم مطلوب';

  @override
  String get version => 'الاصدار';

  @override
  String get videoAdded => 'أُضيف إلى القائمة';

  @override
  String get videoDetails => 'تفاصيل الفيديو';

  @override
  String get videoLabel => 'فيديو';

  @override
  String get videoPlayer => 'مشغّل الفيديو';

  @override
  String get videoRemoved => 'أُزيل من القائمة';

  @override
  String videosCount(int count) {
    return '$count فيديو';
  }

  @override
  String get viewAllInPlaylists => 'عرض الكل';

  @override
  String get waiting => 'بانتظار السيرفر...';

  @override
  String get yourPlaylists => 'قوائمك';

  @override
  String get yourTags => 'وسومك';

  @override
  String get youtubeDownloadStarting => 'جاري بدء تحميل يوتيوب...';
}
