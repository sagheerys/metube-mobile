// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'mt_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class MTLocalizationsAr extends MTLocalizations {
  MTLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get about => 'عن التطبيق';

  @override
  String get aboutApp => 'عن التطبيق';

  @override
  String get aboutDescriptionLite =>
      'تطبيق خفيف وسريع لتحميل الفيديوهات من مختلف المنصات عبر سيرفر MeTube، يسحبها إلى جهازك ثم ينظّف السيرفر، وفيه مشغل مدمج وقوائم تشغيل.';

  @override
  String get aboutDescriptionSuper =>
      'نسخة مالك السيرفر: مكتبة واحدة تجمع ما على السيرفر وما على جهازك، وبثّ من السيرفر، ووسوم، وإتاحة دون اتصال، وتحميل دفعي، وتبديل بين عناوين السيرفر.';

  @override
  String get activeDownloads => 'التحميلات النشطة';

  @override
  String activeDownloadsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count تحميلاً جارياً',
      few: '$count تحميلات جارية',
      two: 'تحميلان جاريان',
      one: 'تحميل واحد جارٍ',
    );
    return '$_temp0';
  }

  @override
  String get activeDownloadsSheet => 'التحميلات الجارية';

  @override
  String get activeNow => 'نشط الآن';

  @override
  String get addEndpoint => 'أضف عنواناً';

  @override
  String get addLinkFab => 'إضافة رابط';

  @override
  String get addTo => 'أضف إلى…';

  @override
  String get addToFavorites => 'أضف للمفضلة';

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
  String addedToPlaylistCount(int count) {
    return 'أُضيف $count إلى القائمة';
  }

  @override
  String get addingToServer => 'جارٍ الإرسال إلى السيرفر…';

  @override
  String get allDownloadsFinished => 'اكتملت جميع التحميلات!';

  @override
  String get allPlatforms => 'كل المنصات';

  @override
  String get alreadyInPlaylist => 'موجود في القائمة';

  @override
  String get alreadySubscribed => 'أنت تتابع هذه القناة بالفعل';

  @override
  String get appTitle => 'MeTube Super';

  @override
  String get appearanceAndLanguage => 'المظهر واللغة';

  @override
  String audioChannels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قناة',
      many: '$count قناة',
      few: '$count قنوات',
      two: 'قناتان',
      one: 'قناة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get audioMono => 'أحادي';

  @override
  String get audioOnly => 'صوت فقط';

  @override
  String get audioStereo => 'ستيريو';

  @override
  String get authHelper => 'اتركه فارغاً إن كان الخادم بلا كلمة مرور';

  @override
  String get authentication => 'تسجيل الدخول (اختياري)';

  @override
  String get autoBuilt => 'تلقائية';

  @override
  String get autoCheckUpdates => 'التحقق تلقائياً';

  @override
  String get autoCheckUpdatesHelp =>
      'يبحث عن إصدار جديد في الخلفية مرتين يومياً تقريباً.';

  @override
  String get autoRestoreSuccess =>
      'استُعيدت البيانات من النسخة الاحتياطية بنجاح!';

  @override
  String get autoRetry => 'إعادة المحاولة عند عودة الشبكة';

  @override
  String get autoRetryHelp =>
      'إذا فشل تحميل بسبب انقطاع الشبكة أعاده التطبيق تلقائياً حين تعود. أما ما رفضه الخادم فلا يُعاد، لأن تكراره دون تغيير سيفشل مجدداً.';

  @override
  String get autoSwitchDisabledHint =>
      'التبديل التلقائي مُعطّل، لذا يستخدم التطبيق عنوان الخادم المحدد في الإعدادات.';

  @override
  String get autoUrlSwitching => 'التبديل التلقائي للعنوان';

  @override
  String get autoUrlSwitchingDesc =>
      'يتصل بالعنوان المحلي متى أمكن الوصول إليه، وبالعنوان الخارجي فيما عدا ذلك';

  @override
  String get availability => 'التوفّر';

  @override
  String get availabilityOffline => 'بلا اتصال (نسخة محلية)';

  @override
  String get availabilityServer => 'الخادم (بث)';

  @override
  String get availableOfflineNow => 'صار متاحاً دون اتصال';

  @override
  String get backgroundDownload => 'جارٍ تحميل الملفات في الخلفية…';

  @override
  String get backupNote =>
      'تشمل النسخة القوائم والوسوم وفهرس المقاطع المتاحة دون اتصال وروابط الأغلفة والإعدادات، ولا تشمل أبداً اسم المستخدم وكلمة المرور، ولا ملفات الوسائط نفسها.';

  @override
  String get backupSettings => 'نسخ جميع البيانات احتياطياً';

  @override
  String get backupSettingsSubtitle =>
      'سبع نسخ مؤرَّخة تتجدد وحدها، استعِد أيّاً منها أو صدّر نسخة لمشاركتها';

  @override
  String backupSuccess(Object path) {
    return 'حُفظت النسخة في: $path';
  }

  @override
  String backupsKept(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نسخة محفوظة',
      many: '$count نسخة محفوظة',
      few: '$count نسخ محفوظة',
      two: 'نسختان محفوظتان',
      one: 'نسخة واحدة محفوظة',
    );
    return '$_temp0';
  }

  @override
  String get batchDownloadSelected => 'تحميل المحدد';

  @override
  String get batchLoading => 'جارٍ قراءة القائمة…';

  @override
  String get batchNothingSelected => 'اختر عنصراً واحداً على الأقل';

  @override
  String get batchSaveToDevice => 'احفظ نسخة على الجهاز';

  @override
  String batchSelectedOf(int selected, int total) {
    return 'حُدِّد $selected من $total';
  }

  @override
  String get batchThisVideoOnly => 'تحميل هذا المقطع فقط';

  @override
  String get batchTitle => 'التحميل الدفعي';

  @override
  String bitrateKbps(String value) {
    return '$value كيلوبت/ث';
  }

  @override
  String bitrateMbps(String value) {
    return '$value ميغابت/ث';
  }

  @override
  String get builtWith => 'بُني باستخدام';

  @override
  String get cancel => 'إلغاء';

  @override
  String get changeQuality => 'تغيير الجودة';

  @override
  String get channelUrl => 'رابط قناة أو قائمة';

  @override
  String get channelUrlHint => 'https://www.youtube.com/@name';

  @override
  String get checkEvery => 'معدّل الفحص';

  @override
  String get checkForUpdates => 'التحقق من التحديثات';

  @override
  String get checkNow => 'افحص الآن';

  @override
  String get checkQueued => 'بدأ الفحص، وسيظهر أي جديد في المكتبة.';

  @override
  String get chooseOptions => 'خيارات';

  @override
  String get cleaningServer => 'جارٍ تنظيف السيرفر...';

  @override
  String get clear => 'مسح';

  @override
  String get clearLogs => 'مسح السجلّات';

  @override
  String get clearLogsConfirm => 'حذف كل سجلّات التشخيص؟';

  @override
  String get clipboardFound => 'رابط جاهز في الحافظة';

  @override
  String get clipboardLinkReady => 'لصق الرابط';

  @override
  String get closePlayer => 'إغلاق المشغل';

  @override
  String get columnAdded => 'تاريخ الإضافة';

  @override
  String get columnLength => 'المدة';

  @override
  String get compactView => 'عرض مختصر';

  @override
  String get compatiblePlayback => 'أفضل توافق للتشغيل';

  @override
  String get compatiblePlaybackHelp =>
      'يطلب من الخادم صيغة H.264/AAC التي تشغّلها كل الهواتف بعتادها مباشرة. وإن أطفأته أتاح لك أعلى دقة، لكن يوتيوب قد يرسل حينها صيغة AV1 فتظهر الصورة مشوّشة على أجهزة كثيرة.';

  @override
  String get completed => 'مكتمل';

  @override
  String get connectionFailed => 'فشل الاتصال';

  @override
  String get connectionSuccessful => 'نجح الاتصال وحُفظت الإعدادات';

  @override
  String get continueAsAudio => 'متابعة بالصوت فقط';

  @override
  String get continueAsAudioBody =>
      'هل تريد متابعة تشغيله صوتاً فقط من اللحظة نفسها؟';

  @override
  String get continueAsAudioNo => 'لا، أوقف';

  @override
  String get continueAsAudioTitle => 'متابعة في الخلفية؟';

  @override
  String get cookies => 'الكوكيز';

  @override
  String get cookiesAbsent => 'السيرفر بلا كوكيز';

  @override
  String get cookiesDelete => 'احذف الكوكيز';

  @override
  String get cookiesDeleteBody =>
      'سيتوقف السيرفر عن استعمالها، وستعود المنصات التي تشترط تسجيل الدخول إلى رفض التحميل.';

  @override
  String get cookiesDeleted => 'حُذفت الكوكيز من السيرفر';

  @override
  String get cookiesHelp =>
      'ثبّت في متصفحك إضافة تصدّر الكوكيز بصيغة Netscape، وصدّر ملفاً لكل منصة، ثم اختر الملفات هنا. سيستعملها السيرفر بعد ذلك في كل تحميل، ويقرر yt-dlp متى يحتاج إليها. وللكوكيز مدة صلاحية، فإذا عاد التحميل إلى الفشل فغالباً حان وقت تصديرها من جديد.';

  @override
  String get cookiesNotNetscape =>
      'لا يحوي أيٌّ من هذه الملفات كوكيز بصيغة Netscape';

  @override
  String get cookiesPresent => 'على السيرفر كوكيز';

  @override
  String get cookiesPrivacy =>
      'يُرسَل الملف إلى سيرفرك مباشرة ولا يُحفظ على هذا الجوال أبداً. ولأنه بمثابة مفتاح لحساباتك، فلا ترفعه إلا إلى سيرفر تملكه.';

  @override
  String get cookiesReplace => 'استبدل ملفات الكوكيز';

  @override
  String get cookiesReplaceNote =>
      'كل رفع جديد يحلّ محل ملف الكوكيز على السيرفر بالكامل، فإن أردت الإبقاء على عدة منصات فاختر ملفاتها كلها معاً في كل مرة، ومنها ما رفعته من قبل. ولاختيار أكثر من ملف، اضغط مطولاً على أول ملف.';

  @override
  String cookiesSentFor(String sites) {
    return 'أُرسلت كوكيز المنصات: $sites';
  }

  @override
  String get cookiesSubtitle => 'للمنصات التي ترفض التحميل بلا تسجيل دخول';

  @override
  String get cookiesTooLarge =>
      'حجم هذا الملف يتجاوز 1 ميغابايت، وهو الحد الأقصى الذي يقبله السيرفر.';

  @override
  String get cookiesUnknown =>
      'إصدار MeTube على سيرفرك لا يتيح معرفة وجود الكوكيز من عدمه';

  @override
  String get cookiesUpload => 'اختر ملفات الكوكيز';

  @override
  String get cookiesUploaded => 'أُرسلت الكوكيز إلى السيرفر';

  @override
  String get cookiesWhat =>
      'بعض المنصات لا تسمح بتحميل المقطع إلا إذا بدا الطلب قادماً من متصفح سُجّل فيه الدخول، وملف الكوكيز المصدَّر من متصفحك يمنح السيرفر هذه الصفة.';

  @override
  String get copiedToClipboard => 'نُسِخ إلى الحافظة';

  @override
  String get copyright => '© 2026 ياسر صغير';

  @override
  String get couldNotLoadPlaylist =>
      'تعذّر فتح هذه القائمة. تحقّق من الرابط ومن اتصالك.';

  @override
  String get create => 'إنشاء';

  @override
  String get createPlaylist => 'إنشاء قائمة';

  @override
  String get creator => 'صانع المحتوى';

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
    return 'حذف $count فيديو؟\n\nستُزال الملفات من جهازك.';
  }

  @override
  String deletePlaylistConfirm(Object name) {
    return 'حذف «$name»؟';
  }

  @override
  String get deleteSelected => 'حذف المحدد';

  @override
  String get deleteTag => 'حذف الوسم';

  @override
  String deleteTagConfirm(Object tag) {
    return 'حذف الوسم «$tag» من كل العناصر؟ لن تُحذف الفيديوهات نفسها.';
  }

  @override
  String get deleteVideo => 'حذف الفيديو';

  @override
  String deleteVideoConfirm(Object title) {
    return 'حذف «$title»؟\n\nسيُزال الملف من جهازك.';
  }

  @override
  String deletedCount(Object count) {
    return 'حُذف $count';
  }

  @override
  String get deletedFromServer => 'حُذف من السيرفر';

  @override
  String deletedTitle(Object title) {
    return 'تم الحذف: $title';
  }

  @override
  String get deselectAll => 'إلغاء التحديد';

  @override
  String get details => 'التفاصيل';

  @override
  String get developer => 'المطور';

  @override
  String get developerName => 'ياسر صغير';

  @override
  String get diagnosticLogs => 'سجلّات التشخيص';

  @override
  String get diagnosticLogsSubtitle =>
      'عرض السجلّات والبحث فيها ومشاركتها، بعد إخفاء البيانات الحساسة';

  @override
  String get disclaimer => 'إخلاء مسؤولية';

  @override
  String get disclaimerText =>
      'يتصل هذا التطبيق بسيرفر MeTube، والمطوّر غير مسؤول عن طريقة استخدامه. يُرجى احترام حقوق النشر وشروط استخدام منصات المحتوى.';

  @override
  String get dismiss => 'تجاهل';

  @override
  String get done => 'تم';

  @override
  String get download => 'تنزيل';

  @override
  String get downloadComplete => 'اكتمل التحميل';

  @override
  String get downloadCompleteTitle => 'اكتمل!';

  @override
  String get downloadDate => 'تاريخ التحميل';

  @override
  String get downloadFailed => 'فشل التحميل';

  @override
  String get downloadFailedTitle => 'فشل التنزيل';

  @override
  String get downloadNow => 'تحميل';

  @override
  String get downloadStarted => 'بدأ التحميل...';

  @override
  String downloadStartedQuality(Object quality) {
    return 'بدأ التحميل · $quality';
  }

  @override
  String get downloading => 'جارٍ التحميل...';

  @override
  String get downloadingTitle => 'جارٍ التنزيل';

  @override
  String get editSubscription => 'تعديل';

  @override
  String get emptyLibraryMessage => 'أضِف رابط فيديو، أو اسحب للتحديث.';

  @override
  String get emptyPlaylist => 'قائمة فارغة';

  @override
  String get emptyPlaylistMessage => 'أضِف فيديوهات من المكتبة';

  @override
  String get endpointUrl => 'عنوان الخادم الخارجي';

  @override
  String get enterFullscreen => 'ملء الشاشة';

  @override
  String get errAuth => 'اسم المستخدم أو كلمة المرور خاطئة';

  @override
  String get errFileGone =>
      'الملف لم يعد على السيرفر. أعد المحاولة لتحميله من جديد.';

  @override
  String get errNetwork => 'تعذر الوصول للسيرفر';

  @override
  String get errNoApi =>
      'العنوان يستجيب، لكن لا تعمل عليه واجهة MeTube البرمجية';

  @override
  String get errNotMeTube => 'هذا العنوان ليس سيرفر MeTube';

  @override
  String get errPlatformBlocked =>
      'المنصة تطلب تسجيل الدخول — على مدير السيرفر تحديث الكوكيز';

  @override
  String get errPlatformBlockedCookies =>
      'المنصة تطلب تسجيل الدخول — ارفع ملف كوكيز من الإعدادات ← الكوكيز';

  @override
  String get errPollTimeout => 'تأخّر ردّ السيرفر — أعد المحاولة';

  @override
  String errServer(Object message) {
    return 'خطأ من السيرفر: $message';
  }

  @override
  String errorGeneric(Object message) {
    return 'خطأ: $message';
  }

  @override
  String get every30Minutes => 'كل نصف ساعة';

  @override
  String everyHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'كل $count ساعة',
      few: 'كل $count ساعات',
      two: 'كل ساعتين',
      one: 'كل ساعة',
    );
    return '$_temp0';
  }

  @override
  String get exitFullscreen => 'خروج من ملء الشاشة';

  @override
  String get exportShare => 'تصدير ومشاركة';

  @override
  String get exportShareSubtitle =>
      'نسخة مؤرَّخة لإرسالها أو حفظها في مكان آخر';

  @override
  String get externalNetworkDesc =>
      'إن تعذّر الوصول إلى العنوان المحلي، جرّب التطبيق العناوين أدناه بالترتيب من الأعلى، واتصل بأول عنوان يستجيب.';

  @override
  String get externalNetworkSection => 'شبكة خارجية';

  @override
  String get externalPlayerShort => 'مشغل خارجي';

  @override
  String get failed => 'فشل';

  @override
  String get failedToLoadPlaylist => 'تعذّر فتح القائمة';

  @override
  String get favorites => 'المفضلة';

  @override
  String get file => 'الملف';

  @override
  String get fileName => 'اسم الملف';

  @override
  String get fileSize => 'حجم الملف';

  @override
  String get filterAll => 'الكل';

  @override
  String get filterAudio => 'صوت';

  @override
  String get filterOffline => 'بلا اتصال';

  @override
  String get filterServer => 'الخادم';

  @override
  String get filterVideo => 'فيديو';

  @override
  String get follow => 'متابعة';

  @override
  String get followChannel => 'تابِع قناة';

  @override
  String get format => 'الصيغة';

  @override
  String framesPerSecond(int count) {
    return '$count إطار/ث';
  }

  @override
  String get helpAboutField => 'عن هذا الحقل';

  @override
  String get inPlaylists => 'في قوائم التشغيل';

  @override
  String get invalidUrl => 'أدخل رابطاً صالحاً';

  @override
  String get itemOptions => 'خيارات العنصر';

  @override
  String get itemUnavailable => 'لم يعد متوفراً';

  @override
  String knownVideos(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مقطع مرصود',
      many: '$count مقطعاً مرصوداً',
      few: '$count مقاطع مرصودة',
      two: 'مقطعان مرصودان',
      one: 'مقطع مرصود',
      zero: 'لم يُرصد أي مقطع بعد',
    );
    return '$_temp0';
  }

  @override
  String get language => 'اللغة';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSystem => 'النظام';

  @override
  String get languageSystemHint => 'يتبع لغة هاتفك';

  @override
  String lastBackup(String when) {
    return 'آخر نسخة $when';
  }

  @override
  String lastCheckedAt(String when) {
    return 'آخر تحقق $when';
  }

  @override
  String get latestAdditions => 'أحدث الإضافات';

  @override
  String get licensedUnder => 'مرخَّص برخصة GPL-3.0';

  @override
  String get licenses => 'تراخيص البرمجيات مفتوحة المصدر';

  @override
  String get listSeparator => '، ';

  @override
  String get listenInBackground => 'الاستماع في الخلفية';

  @override
  String get localCopyRemoved => 'أُزيلت النسخة المحلية';

  @override
  String get localNetworkDesc =>
      'يتصل التطبيق بالخادم عبر هذا العنوان متى أمكن الوصول إليه.';

  @override
  String get localNetworkSection => 'شبكة محلية';

  @override
  String get localUrlLabel => 'عنوان الخادم المحلي';

  @override
  String get lockTouch => 'قفل اللمس';

  @override
  String get logsEmpty => 'السجل فارغ';

  @override
  String get logsSanitizedNote =>
      'تُحذف الروابط والعناوين وبيانات الدخول قبل المشاركة';

  @override
  String get madeOffline => 'صار متاحاً دون اتصال';

  @override
  String get makeOffline => 'إتاحة دون اتصال';

  @override
  String get manageTags => 'إدارة الوسوم';

  @override
  String get mediaAccessBlockedMessage =>
      'لن يعرض أندرويد طلب الإذن مجدداً، ففعّل «الصور ومقاطع الفيديو» لهذا التطبيق من إعدادات النظام ثم عُد إليه.';

  @override
  String get mediaAccessGrant => 'السماح';

  @override
  String get mediaAccessMessage =>
      'تنزيلاتك محفوظة في مجلد Download في هاتفك، وأندرويد يطلب إذنك قبل أن يعرضها التطبيق.';

  @override
  String get mediaAccessOpenSettings => 'فتح الإعدادات';

  @override
  String get mediaAccessTitle => 'اسمح بالوصول إلى الوسائط';

  @override
  String get metubeCredit => 'الخادم ذاتي الاستضافة الذي يتصل به التطبيق';

  @override
  String get modeAutoNext => 'تلقائي';

  @override
  String get modeRepeatAll => 'تكرار الكل';

  @override
  String get modeRepeatOne => 'تكرار الحالي';

  @override
  String get modeStopAtEnd => 'التوقف في النهاية';

  @override
  String get navLibrary => 'المكتبة';

  @override
  String get navMyDownloads => 'تحميلاتي';

  @override
  String get navPlaylists => 'القوائم';

  @override
  String get navSettings => 'الإعدادات';

  @override
  String get needsAttention => 'تحتاج انتباهك';

  @override
  String get networkSettings => 'الشبكات';

  @override
  String get networkSettingsSubtitle =>
      'التبديل التلقائي بين عناوين الخادم المحلية والخارجية';

  @override
  String get neverChecked => 'لم يُتحقَّق بعد';

  @override
  String newFromSubscriptions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مقطع جديد من قنواتك',
      many: '$count مقطعاً جديداً من قنواتك',
      few: '$count مقاطع جديدة من قنواتك',
      two: 'مقطعان جديدان من قنواتك',
      one: 'مقطع جديد من قناة تتابعها',
      zero: 'لا جديد',
    );
    return '$_temp0';
  }

  @override
  String get newPlaylistAction => 'قائمة جديدة';

  @override
  String get newTagHint => 'وسم جديد';

  @override
  String get next => 'التالي';

  @override
  String get noBackupsYet => 'لا توجد نسخ بعد';

  @override
  String get noDownloads => 'لا توجد تحميلات';

  @override
  String get noDownloadsMessage =>
      'ستظهر هنا الفيديوهات التي تحمّلها.\nشارك رابط فيديو أو اضغط زر «إضافة رابط».';

  @override
  String get noExternalPlayer => 'لا يوجد مشغل خارجي على الجهاز';

  @override
  String get noLogsFound => 'لا توجد سجلّات';

  @override
  String get noPlayableSource => 'لا مصدر لتشغيل هذا العنصر';

  @override
  String get noPlaylistsMessage => 'أنشئ قائمة لتنظيم فيديوهاتك';

  @override
  String get noResults => 'لا نتائج';

  @override
  String get noResultsMessage => 'لا توجد عناصر مطابقة لبحثك.';

  @override
  String get noServerMessage =>
      'أدخل رابط سيرفر MeTube من الإعدادات لبدء التحميل';

  @override
  String get noServerTitle => 'لا سيرفر بعد';

  @override
  String get noTagsYet => 'لا وسوم بعد، أنشئ أول وسم من الأسفل.';

  @override
  String get noVideosFound => 'مكتبتك فارغة';

  @override
  String get noWarranty => 'يُقدَّم كما هو، بلا أي ضمان.';

  @override
  String get notAffiliated =>
      'تطبيق غير رسمي، لا صلة له بمشروع MeTube ولا yt-dlp، ولا يحظى بتأييدهما.';

  @override
  String get nothingHereYet => 'لا يوجد شيء بعد';

  @override
  String get notifyArrivals => 'نبّهني بما يصل تلقائياً';

  @override
  String get notifyArrivalsDesc =>
      'يصلك إشعار واحد حين تصل إلى السيرفر مقاطع جديدة من قناة تتابعها، ويظهر عند فتح التطبيق أو العودة إليه أو تحديث المكتبة، لا أثناء عمله في الخلفية.';

  @override
  String get nowPlaying => 'قيد التشغيل';

  @override
  String get nowPlayingCollapse => 'طيّ لوحة التشغيل';

  @override
  String get nowPlayingExpand => 'إظهار لوحة التشغيل';

  @override
  String get offlineSmartList => 'دون اتصال';

  @override
  String get ok => 'حسناً';

  @override
  String get onServerPhase => 'على السيرفر';

  @override
  String onServerProgress(Object percent) {
    return 'على السيرفر · $percent٪';
  }

  @override
  String get onlyNewVideos =>
      'لا يُنزَّل إلا ما يُنشر من الآن فصاعداً، أما ما نُشر في القناة من قبل فلا يُنزَّل.';

  @override
  String get openChannel => 'فتح القناة';

  @override
  String get openInExternalPlayer => 'فتح في مشغل خارجي';

  @override
  String get openOriginalLink => 'فتح الرابط الأصلي';

  @override
  String get password => 'كلمة المرور';

  @override
  String get pasteUrlHint => 'الصق الرابط هنا…';

  @override
  String get pause => 'إيقاف مؤقت';

  @override
  String get pauseSubscription => 'إيقاف مؤقت';

  @override
  String percentValue(Object percent) {
    return '$percent٪';
  }

  @override
  String get pickAnotherFile => 'من ملف آخر…';

  @override
  String get pickAnotherFileSubtitle => 'نسخة من هاتف آخر أو من إصدار سابق';

  @override
  String get pinPlaylist => 'تثبيت في الصدارة';

  @override
  String get platform => 'المنصّة';

  @override
  String platformCount(Object name, int count) {
    return '$name · $count';
  }

  @override
  String get platformOther => 'أخرى';

  @override
  String get play => 'تشغيل';

  @override
  String get playAll => 'تشغيل الكل';

  @override
  String get playModeLabel => 'الوضع';

  @override
  String get playbackSpeed => 'سرعة التشغيل';

  @override
  String get playerError => 'تعذّر تشغيل هذا الملف';

  @override
  String get playingFromDevice => 'يُشغَّل من جهازك';

  @override
  String get playlist => 'قائمة التشغيل';

  @override
  String get playlistCreated => 'أُنشئت القائمة';

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
  String get preferences => 'التفضيلات';

  @override
  String get previous => 'السابق';

  @override
  String get pullingToDevice => 'جارٍ الحفظ في الجهاز…';

  @override
  String pullingToDeviceProgress(Object percent) {
    return 'جارٍ الحفظ في الجهاز · $percent٪';
  }

  @override
  String get quality => 'الجودة';

  @override
  String get quality1080 => '1080p';

  @override
  String get quality480 => '480p';

  @override
  String get quality720 => '720p';

  @override
  String get qualityAudio => 'الصوت';

  @override
  String get qualityBest => 'الأفضل';

  @override
  String get qualityHelper =>
      'تُعتمد هذه الجودة في التحميل السريع، وفي تحميل القائمة كاملة، وفي «حمّل الآن» من شريط الحافظة، وتكون محددة مسبقاً في نافذة إضافة الرابط؛ لذا يسري أثرها سواء أكان التحميل السريع مفعّلاً أم لا.';

  @override
  String get qualityReading => 'جارٍ قراءة الملف…';

  @override
  String get qualityUnavailable => 'غير متاحة';

  @override
  String get qualityVideo => 'الفيديو';

  @override
  String queueItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عنصراً',
      few: '$count عناصر',
      two: 'عنصران',
      one: 'عنصر واحد',
      zero: 'لا عناصر',
    );
    return '$_temp0';
  }

  @override
  String get queueLabel => 'قائمة الانتظار';

  @override
  String get queued => 'في الانتظار';

  @override
  String get queuedSection => 'بالانتظار';

  @override
  String get quickDownload => 'التحميل السريع';

  @override
  String get quickDownloadHelp =>
      'حين تشارك رابطاً أو تلصقه يبدأ تحميله فوراً بالجودة الافتراضية دون أي نافذة. الجودات الرقمية خاصة بيوتيوب، فما سواه يُحمَّل بأفضل جودة، أما «صوت فقط» فيسري على كل المنصات.';

  @override
  String get reelsEndBack => 'عودة للمكتبة';

  @override
  String get reelsEndContinue => 'متابعة بقية القائمة';

  @override
  String get reelsEndReplay => 'إعادة من البداية';

  @override
  String get reelsEndTitle => 'وصلت إلى آخر القِصار';

  @override
  String get reelsSwipeHint => 'اسحب لأعلى للمقطع التالي';

  @override
  String get refresh => 'تحديث';

  @override
  String get remove => 'إزالة';

  @override
  String get removeFromFavorites => 'إزالة من المفضلة';

  @override
  String get removeLocalCopy => 'إزالة النسخة المحلية';

  @override
  String removeUnavailable(int count) {
    return 'إزالة غير المتوفر ($count)';
  }

  @override
  String get removedFromFavorites => 'أُزيل من المفضلة';

  @override
  String get removedFromPlaylist => 'أُزيل من القائمة';

  @override
  String get rename => 'إعادة تسمية';

  @override
  String get renameTag => 'إعادة تسمية الوسم';

  @override
  String get reportBug => 'الإبلاغ عن مشكلة';

  @override
  String get restoreConfirm =>
      'هل تريد استعادة البيانات من النسخة الاحتياطية؟ ستحلّ محل قوائمك ووسومك وإعداداتك الحالية.';

  @override
  String get restoreData => 'استعادة';

  @override
  String get restoreFailed => 'فشلت الاستعادة — ملف النسخة الاحتياطية غير صالح';

  @override
  String get restoreSettings => 'استعادة جميع البيانات';

  @override
  String get restoreSuccess => 'استُعيدت البيانات بنجاح';

  @override
  String resultsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count نتيجة',
      few: '$count نتائج',
      two: 'نتيجتان',
      one: 'نتيجة واحدة',
      zero: 'لا نتائج',
    );
    return '$_temp0';
  }

  @override
  String get resumeSubscription => 'استئناف';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get saveSettings => 'حفظ الإعدادات';

  @override
  String get saveToDevice => 'حفظ في الجهاز';

  @override
  String get savedOnDevice => 'محفوظ في الجهاز';

  @override
  String get searchLogs => 'بحث في السجلّات…';

  @override
  String get searchVideos => 'بحث في الفيديوهات…';

  @override
  String get seekBackward10 => 'إرجاع ١٠ ثوانٍ';

  @override
  String get seekForward10 => 'تقديم ١٠ ثوانٍ';

  @override
  String get selectAll => 'تحديد الكل';

  @override
  String selected(int count) {
    return 'المحدد: $count';
  }

  @override
  String selectedCount(int count) {
    return 'المحدد: $count';
  }

  @override
  String get serverConfiguration => 'إعداد الخادم';

  @override
  String serverFilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ملفاً على الخادم',
      few: '$count ملفات على الخادم',
      two: 'ملفان على الخادم',
      one: 'ملف واحد على الخادم',
      zero: 'لا ملفات على الخادم',
    );
    return '$_temp0';
  }

  @override
  String get serverKeepsFilesBody =>
      'يُحذف العنصر من السجل لكن ملفه يبقى على القرص، فتمتلئ مساحة الخادم. اضبط DELETE_FILE_ON_TRASHCAN=true في حاوية MeTube.';

  @override
  String get serverKeepsFilesTitle => 'خادمك لا يحذف الملفات';

  @override
  String serverQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count في الانتظار',
      few: '$count في الانتظار',
      two: 'اثنان في الانتظار',
      one: 'واحد في الانتظار',
      zero: '',
    );
    return '$_temp0';
  }

  @override
  String get serverStatusChecking => 'جارٍ فحص الاتصال…';

  @override
  String get serverStatusConnected => 'متصل بالخادم';

  @override
  String get serverStatusOffline => 'تعذّر الوصول للخادم';

  @override
  String get serverStatusUnconfigured => 'لم يُضبط الخادم';

  @override
  String get serverUnreachableLocalHint =>
      'ما زال بإمكانك تشغيل المقاطع المحفوظة على هاتفك.';

  @override
  String get serverUrl => 'رابط السيرفر (MeTube)';

  @override
  String get serverUrlHelpBody =>
      'عنوان خادم MeTube، مثل http://192.168.1.10:8081. في المنزل استخدم عنوان IP المحلي مع HTTP العادي، ومن خارج المنزل استخدم عنوان HTTPS (مثل Cloudflare Tunnel).';

  @override
  String get serverUrlHelpTitle => 'حول رابط السيرفر';

  @override
  String get serverUrlHint => 'http://192.168.1.5:8086 أو https://domain.com';

  @override
  String get serverUrlRequired => 'رابط الخادم مطلوب';

  @override
  String serverVersionLabel(String version) {
    return 'MeTube $version';
  }

  @override
  String serverVersionOutdated(String latest) {
    return 'يتوفر تحديث: $latest';
  }

  @override
  String get serverVersionUnknown => 'الإصدار غير معروف';

  @override
  String get settings => 'الإعدادات';

  @override
  String get settingsBackup => 'النسخ الاحتياطي';

  @override
  String get settingsDownloads => 'التحميل';

  @override
  String get settingsGroupApp => 'التطبيق';

  @override
  String get settingsGroupData => 'البيانات';

  @override
  String get settingsGroupServer => 'السيرفر';

  @override
  String get settingsPlayback => 'التشغيل';

  @override
  String get settingsSaved => 'حُفظت الإعدادات';

  @override
  String get settingsTranscripts => 'النصوص والترجمة';

  @override
  String get settingsValueArrivals => 'إشعار بما يصل';

  @override
  String get settingsValueAuto => 'تلقائي';

  @override
  String settingsValueChannels(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قناة',
      many: '$count قناة',
      few: '$count قنوات',
      two: 'قناتان',
      one: 'قناة واحدة',
      zero: 'لا قنوات بعد',
    );
    return '$_temp0';
  }

  @override
  String get settingsValueCompatOff => 'أفضل توافق: معطّل';

  @override
  String get settingsValueCompatOn => 'أفضل توافق: مفعّل';

  @override
  String get settingsValueExternalNow => 'الخارجي الآن';

  @override
  String get settingsValueLocalNow => 'المحلي الآن';

  @override
  String get settingsValueManual => 'يدوي';

  @override
  String get settingsValueNoPassword => 'بلا كلمة مرور';

  @override
  String get settingsValueNotSet => 'لم يُضبط بعد';

  @override
  String get settingsValueOff => 'معطّل';

  @override
  String get settingsValueOn => 'مفعّل';

  @override
  String get settingsValueQuick => 'سريع';

  @override
  String get settingsValueSubtitlesShown => 'الترجمة ظاهرة';

  @override
  String get settingsValueWifiOnly => 'Wi‑Fi فقط';

  @override
  String get setupServer => 'إعداد السيرفر';

  @override
  String get share => 'مشاركة';

  @override
  String get shareLogs => 'مشاركة السجلات';

  @override
  String get shareSelected => 'مشاركة المحدد';

  @override
  String get shortsFilter => 'قِصار';

  @override
  String showChannel(String channel) {
    return 'كل مقاطع $channel';
  }

  @override
  String get shuffle => 'تشغيل عشوائي';

  @override
  String get signInRequired => 'يلزم تسجيل الدخول';

  @override
  String get signInRequiredHint =>
      'رفض السيرفر بيانات الدخول المحفوظة. حدّث اسم المستخدم وكلمة المرور في الإعدادات.';

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
  String get sortedByLastPlayed => 'حسب آخر تشغيل';

  @override
  String get source => 'المصدر';

  @override
  String get sourceCode => 'الشيفرة المصدرية';

  @override
  String get startDownload => 'ابدأ التحميل';

  @override
  String get status => 'الحالة';

  @override
  String get streamingFromServer => 'يُبثّ من السيرفر';

  @override
  String subscriptionAdded(String name) {
    return 'تتابع الآن $name';
  }

  @override
  String get subscriptionName => 'الاسم';

  @override
  String get subscriptionPaused => 'موقوفة مؤقتاً';

  @override
  String get subscriptionQuality => 'جودة التنزيل لهذه القناة';

  @override
  String get subscriptionQualityHelp =>
      'يثبّت السيرفر الجودة التي تختارها عند المتابعة ولا يسمح بتغييرها. لتغييرها اضغط «افحص الآن» أولاً، ثم ألغِ المتابعة وتابع القناة من جديد.\n\nقد يعني «الأفضل» دقة 4K بترميز AV1، وهي تعمل بسلاسة على الجوالات الحديثة. فإن رأيت تقطيعاً فجوالك لا يفك ترميز AV1 عتادياً: اختر 1080p، أو فعّل «أفضل توافق للتشغيل» قبل المتابعة.';

  @override
  String get subscriptionQualityNote => 'لا تُغيَّر بعد المتابعة.';

  @override
  String get subscriptions => 'الاشتراكات';

  @override
  String get subscriptionsEmpty => 'لا قنوات متابَعة بعد';

  @override
  String get subscriptionsEmptyBody =>
      'تابِع قناة، وسينزّل السيرفر تلقائياً كل مقطع جديد تنشره ليصل إلى مكتبتك مباشرة. أما ما نُشر قبل المتابعة فلا يُنزَّل.';

  @override
  String get subscriptionsSubtitle => 'قنوات يتابعها السيرفر نيابةً عنك';

  @override
  String get subscriptionsUnsupported => 'نسخة MeTube لديك لا تدعم الاشتراكات';

  @override
  String get subscriptionsUnsupportedBody =>
      'حدّث حاوية MeTube إلى إصدار يدعم اشتراكات القنوات، ثم عد إلى هنا. بقية ميزات التطبيق تعمل كالمعتاد.';

  @override
  String get subtitles => 'الترجمة على الفيديو';

  @override
  String get subtitlesBackground => 'الخلفية';

  @override
  String get subtitlesBackgroundFaint => 'خفيفة';

  @override
  String get subtitlesBackgroundHelp =>
      'اللون الذي يظهر خلف الكلمات. وإن اخترت «بلا خلفية» أحاط بكل حرف حدٌّ داكن ليبقى مقروءاً فوق الصور الفاتحة.';

  @override
  String get subtitlesBackgroundNone => 'بلا خلفية';

  @override
  String get subtitlesBackgroundSolid => 'داكنة';

  @override
  String get subtitlesHide => 'إخفاء الترجمة';

  @override
  String get subtitlesInShorts => 'الترجمة في الشورتس';

  @override
  String get subtitlesInShortsHelp =>
      'معطّلة افتراضياً، لأن كثيراً من الشورتس يُكتب كلامها على الصورة أصلاً.';

  @override
  String get subtitlesLanguage => 'لغة الترجمة';

  @override
  String get subtitlesShow => 'إظهار الترجمة';

  @override
  String get subtitlesShowHelp =>
      'تظهر فوق الفيديو في المقاطع التي لها نص، ويؤدي زر CC في المشغّل العمل نفسه.';

  @override
  String get subtitlesSize => 'حجم الخط';

  @override
  String get subtitlesSizeLarge => 'كبير';

  @override
  String get subtitlesSizeMedium => 'متوسط';

  @override
  String get subtitlesSizeSmall => 'صغير';

  @override
  String get tagActionsHint => 'اضغط مطوّلاً على وسم لإعادة تسميته أو حذفه.';

  @override
  String get tags => 'الوسوم';

  @override
  String get tagsOpenFiltered => 'تفتح المكتبة مصفّاةً بالوسم';

  @override
  String get testingConnection => 'جارٍ اختبار الاتصال…';

  @override
  String get theme => 'السمة';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeSystem => 'حسب النظام';

  @override
  String get titleFilter => 'نزّل فقط المقاطع التي يحتوي عنوانها على';

  @override
  String get titleFilterHelp =>
      'لا ينزّل السيرفر مقطعاً جديداً من هذه القناة إلا إذا احتوى عنوانه على ما تكتبه هنا.\n\n• كلمة عادية تكفي: الحلقة\n• أيّ كلمة من عدة كلمات: الحلقة|الجزء — العلامة | تعني «أو»\n• في الإنجليزية يُفرَّق بين الأحرف الكبيرة والصغيرة: episode لا تطابق Episode. اكتب ‎[Ee]pisode‎ أو اكتب الصيغتين.\n\nوالمقطع الذي يتخطاه الفلتر يُعدّ مُشاهَداً إلى الأبد، فإن أزلت الفلتر لاحقاً نُزِّل ما يُنشر بعد ذلك فقط، لا ما تخطّاه.';

  @override
  String get titleFilterHelper =>
      'لعدة كلمات افصل بينها بـ | ، واتركه فارغاً لتنزيل كل شيء.';

  @override
  String get titleFilterHint => 'مثال: الحلقة';

  @override
  String get titleLabel => 'العنوان';

  @override
  String totalDuration(Object duration) {
    return 'الإجمالي: $duration';
  }

  @override
  String get transcript => 'النص';

  @override
  String get transcriptFind => 'ابحث في النص';

  @override
  String get transcriptFull => 'النص الكامل';

  @override
  String transcriptMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count موضع',
      many: '$count موضعاً',
      few: '$count مواضع',
      two: 'موضعان',
      one: 'موضع واحد',
      zero: 'لا مواضع',
    );
    return '$_temp0';
  }

  @override
  String get transcriptNextMatch => 'الموضع التالي';

  @override
  String get transcriptPreviousMatch => 'الموضع السابق';

  @override
  String transcriptSaidMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'قيلت $count مرة أخرى',
      many: 'قيلت $count مرة أخرى',
      few: 'قيلت $count مرات أخرى',
      two: 'قيلت مرتين أخريين',
      one: 'قيلت مرة أخرى',
    );
    return '$_temp0';
  }

  @override
  String transcriptsClips(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مقطع',
      many: '$count مقطعاً',
      few: '$count مقاطع',
      two: 'مقطعان',
      one: 'مقطع واحد',
      zero: 'لا مقاطع بعد',
    );
    return '$_temp0';
  }

  @override
  String get transcriptsDeleteAll => 'حذف الكل';

  @override
  String get transcriptsDeleteBody =>
      'تُحذف من هذا الجوال، ولا يعيدها إلا ملف صدّرته.';

  @override
  String get transcriptsDeleteTitle => 'حذف كل النصوص؟';

  @override
  String transcriptsDisableBody(String size) {
    return 'النصوص المحفوظة ($size) تبقى في هذا الجوال ما لم تحذفها.';
  }

  @override
  String get transcriptsDisableTitle => 'إيقاف البحث داخل المقاطع؟';

  @override
  String get transcriptsEnable => 'تفعيل';

  @override
  String get transcriptsEnableBody =>
      'حين تضيف مقطع يوتيوب، يجلب التطبيق نصّه من سيرفرك قبل تنزيله، بلغة التطبيق وبالإنجليزية، وقد يستغرق ذلك حتى 40 ثانية، ثم يحفظه في هذا الجوال وحده. أما المقاطع الموجودة في مكتبتك فلا تُشمل إلا إن كان سيرفرك يحفظ ملف الترجمة بجانب كل منها (يشرح دليل الإعداد طريقة ذلك). ويمكنك إيقاف الميزة متى شئت.';

  @override
  String get transcriptsExport => 'تصدير';

  @override
  String transcriptsExported(Object path) {
    return 'حُفظت النصوص في: $path';
  }

  @override
  String get transcriptsHelp =>
      'يحفظ التطبيق ما يُقال في كل مقطع يوتيوب تضيفه، فيبحث بحث المكتبة في كلام مقاطعك لا في عناوينها وحدها.\n\nيُجلب الكلام من سيرفرك قبيل التنزيل ويُحفظ في هذا الجوال، ولا تشمله النسخة الاحتياطية الكاملة. لنقله إلى جوال آخر استعمل «تصدير» هنا و«استيراد» هناك، والاستيراد يضيف إلى الموجود ولا يحذف شيئاً.\n\nوإن ضبطت سيرفرك ليحفظ ملف الترجمة بجانب كل مقطع (سطر واحد في إعداداته يشرحه دليل الإعداد)، شُمل كل ما ينزّله من ذلك الحين، بما فيه مقاطع الاشتراكات والمواقع الأخرى، إذ يقرأ التطبيق تلك الملفات تلقائياً بلغة التطبيق وبالإنجليزية.';

  @override
  String get transcriptsImport => 'استيراد';

  @override
  String get transcriptsImportInvalid => 'هذا الملف لا يحوي نصوصاً.';

  @override
  String transcriptsImported(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'استُورد $count نص',
      many: 'استُورد $count نصاً',
      few: 'استُورد $count نصوص',
      two: 'استُورد نصّان',
      one: 'استُورد نص واحد',
    );
    return '$_temp0';
  }

  @override
  String get transcriptsKeep => 'إيقاف والاحتفاظ بالنصوص';

  @override
  String get transcriptsSaidInside => 'قيل داخل المقاطع';

  @override
  String get transcriptsSearch => 'البحث داخل المقاطع';

  @override
  String get transcriptsSearchHelp =>
      'يحفظ ما يُقال في كل مقطع يوتيوب تضيفه، لتبحث في كلامه لا في عنوانه وحده.';

  @override
  String get transcriptsStopAndDelete => 'إيقاف وحذف';

  @override
  String get tryAgain => 'حاول مرة أخرى';

  @override
  String get undo => 'تراجع';

  @override
  String get unfollow => 'إلغاء المتابعة';

  @override
  String unfollowConfirm(String name) {
    return 'إلغاء متابعة $name؟';
  }

  @override
  String get unfollowConfirmBody =>
      'سينسى السيرفر المقاطع التي سبق أن رآها من هذه القناة. فإن تابعتها لاحقاً عُدَّ كل ما عليها حينها مُشاهَداً، ولن يُنزَّل ما فاتك. أما الإيقاف المؤقت فيحفظ هذا السجل.';

  @override
  String get unlockTouch => 'فك القفل';

  @override
  String get unpinPlaylist => 'إلغاء التثبيت';

  @override
  String get upNext => 'التالي';

  @override
  String upNextIn(String name) {
    return 'التالي في «$name»';
  }

  @override
  String get updateAllowInstallBody =>
      'يطلب أندرويد إذنك قبل أن يثبّت التطبيق تحديثاته بنفسه. امنحه مرة واحدة من إعدادات النظام، ثم عد واضغط «تثبيت».';

  @override
  String get updateAllowInstallTitle => 'السماح بتثبيت التحديثات';

  @override
  String get updateAvailable => 'يتوفّر تحديث';

  @override
  String get updateCheckFailed => 'تعذّر التحقق من التحديثات';

  @override
  String get updateChecking => 'جارٍ التحقق…';

  @override
  String get updateCredentials => 'تحديث بيانات الدخول';

  @override
  String get updateDownloadFailed => 'تعذّر تنزيل التحديث';

  @override
  String get updateDownloading => 'جارٍ تنزيل التحديث…';

  @override
  String get updateFailedToStart => 'تعذّر فتح شاشة التثبيت';

  @override
  String get updateInstall => 'تثبيت';

  @override
  String get updateLater => 'لاحقاً';

  @override
  String get updateNever => 'لم يحدث بعد';

  @override
  String get updateNow => 'تنزيل التحديث';

  @override
  String get updateOpenSystemSettings => 'فتح الإعدادات';

  @override
  String get updateReady => 'جاهز للتثبيت';

  @override
  String updateSizeMb(String size) {
    return '$size ميغابايت';
  }

  @override
  String get updateSkipVersion => 'تخطّي هذا الإصدار';

  @override
  String get updateUpToDate => 'لديك أحدث إصدار';

  @override
  String updateVersionAvailable(String version) {
    return 'الإصدار $version متاح';
  }

  @override
  String get updateWhatsNew => 'ما الجديد';

  @override
  String get updates => 'التحديثات';

  @override
  String get username => 'اسم المستخدم';

  @override
  String get version => 'الإصدار';

  @override
  String get videoAdded => 'أُضيف إلى القائمة';

  @override
  String get videoPlayer => 'مشغّل الفيديو';

  @override
  String get viewAll => 'عرض الكل';

  @override
  String get viewAllInPlaylists => 'عرض الكل';

  @override
  String get viewCards => 'بطاقات';

  @override
  String get viewGrid => 'شبكة';

  @override
  String get viewList => 'قائمة';

  @override
  String get viewMode => 'العرض';

  @override
  String get waitingForWifi => 'بانتظار Wi‑Fi';

  @override
  String get whatsNewGotIt => 'حسناً';

  @override
  String get whatsNewReleasePage => 'صفحة الإصدار';

  @override
  String get whatsNewThisVersion => 'الجديد في هذا الإصدار';

  @override
  String whatsNewTitle(String version) {
    return 'الجديد في الإصدار $version';
  }

  @override
  String get whatsNewUnavailable =>
      'ما تغيّر في هذا الإصدار تجده في صفحة الإصدار.';

  @override
  String get wifiOnly => 'التحميل عبر Wi‑Fi فقط';

  @override
  String get wifiOnlyHelp =>
      'لا تُسحب الملفات إلى جهازك عبر بيانات الجوّال، بل تنتظر المهام وتُستأنف تلقائياً عند الاتصال بشبكة Wi‑Fi.';

  @override
  String get yourPlaylists => 'قوائمك';

  @override
  String get yourTags => 'وسومك';

  @override
  String get ytdlpCredit => 'أداة التنزيل التي يعتمد عليها MeTube';
}
