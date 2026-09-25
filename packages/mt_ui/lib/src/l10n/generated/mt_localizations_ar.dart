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
  String get aboutDescriptionLite =>
      'تطبيق خفيف وسريع لتحميل الفيديوهات من مختلف المنصات عبر سيرفر MeTube، يسحبها إلى جهازك وينظّف السيرفر بعدها — مع مشغل مدمج وقوائم تشغيل.';

  @override
  String get aboutDescriptionSuper =>
      'نسخة مالك السيرفر: مكتبة موحّدة من السيرفر وجهازك، بثّ مباشر ووسوم وإتاحة دون اتصال وتحميل دفعي وتبديل بين عناوين السيرفر.';

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
  String get addEndpoint => 'أضف نقطة نهاية';

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
  String get addingToServer => 'يُرسَل للسيرفر…';

  @override
  String get allDownloadsFinished => 'اكتملت جميع التحميلات!';

  @override
  String get allPlatforms => 'كل المنصات';

  @override
  String get alreadyInPlaylist => 'مضاف مسبقاً';

  @override
  String get alreadySubscribed => 'هذه القناة متابَعة أصلاً';

  @override
  String get appTitle => 'MeTube Super';

  @override
  String audioChannels(int count) {
    return '$count قنوات';
  }

  @override
  String get audioMono => 'أحادي';

  @override
  String get audioOnly => 'صوت فقط';

  @override
  String get audioStereo => 'ستيريو';

  @override
  String get authHelper => 'اتركه فارغاً للخوادم المفتوحة (بلا كلمة مرور)';

  @override
  String get authentication => 'المصادقة (اختياري)';

  @override
  String get autoBuilt => 'تلقائية';

  @override
  String get autoCheckUpdates => 'التحقق تلقائياً';

  @override
  String get autoCheckUpdatesHelp =>
      'يبحث عن إصدار جديد في الخلفية مرتين يومياً تقريباً.';

  @override
  String get autoRestoreSuccess =>
      'تمت استعادة البيانات من النسخة الاحتياطية بنجاح!';

  @override
  String get autoRetry => 'إعادة المحاولة عند عودة الشبكة';

  @override
  String get autoRetryHelp =>
      'ما فشل بسبب انقطاع الشبكة يُعاد وحده عند عودتها. ما رفضه الخادم لا يُعاد — إعادته بلا تغيير تفشل مرة أخرى.';

  @override
  String get autoSwitchDisabledHint =>
      'التبديل التلقائي مُعطّل — يستخدم التطبيق عنوان الخادم الوحيد من الإعدادات.';

  @override
  String get autoUrlSwitching => 'تبديل URL تلقائي';

  @override
  String get autoUrlSwitchingDesc =>
      'اتصل عبر العنوان المحلي عند إمكانية الوصول إليه، واستخدم الاتصالات الخارجية في الأماكن الأخرى';

  @override
  String get availability => 'التوفّر';

  @override
  String get availabilityOffline => 'بلا اتصال (نسخة محلية)';

  @override
  String get availabilityServer => 'الخادم (بث)';

  @override
  String get availableOfflineNow => 'صار متاحاً دون اتصال';

  @override
  String get backgroundDownload => 'جاري تحميل الملفات في الخلفية...';

  @override
  String get backupNote =>
      'يشمل القوائم والوسوم وفهرس عدم الاتصال وروابط الأغلفة والإعدادات. لا تُنسخ كلمة المرور ولا اسم المستخدم أبداً، ولا تُنسخ ملفات الوسائط.';

  @override
  String get backupSettings => 'نسخ جميع البيانات احتياطياً';

  @override
  String get backupSettingsSubtitle =>
      'سبع نسخ مؤرَّخة تتجدد وحدها — استعِد أيّها، أو صدّر نسخة للمشاركة';

  @override
  String backupSuccess(Object path) {
    return 'حُفظت النسخة في: $path';
  }

  @override
  String backupsKept(int count) {
    return '$count نسخ محفوظة';
  }

  @override
  String get batchDownloadSelected => 'تحميل المحدد';

  @override
  String get batchLoading => 'قراءة القائمة…';

  @override
  String get batchNothingSelected => 'اختر عنصراً واحداً على الأقل';

  @override
  String get batchSaveToDevice => 'احفظ نسخة على الجهاز';

  @override
  String batchSelectedOf(int selected, int total) {
    return 'محدد $selected من $total';
  }

  @override
  String get batchThisVideoOnly => 'تحميل هذا المقطع فقط';

  @override
  String get batchTitle => 'التحميل الدفعي';

  @override
  String bitrateKbps(String value) {
    return '$value ك.ب/ث';
  }

  @override
  String bitrateMbps(String value) {
    return '$value م.ب/ث';
  }

  @override
  String get builtWith => 'مبنيّ على';

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
  String get checkQueued => 'بدأ الفحص. وما يجده يظهر في المكتبة.';

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
  String get compactView => 'عرض مدمج';

  @override
  String get compatiblePlayback => 'أفضل توافق للتشغيل';

  @override
  String get compatiblePlaybackHelp =>
      'يطلب من الخادم صيغة H.264/AAC التي تفكّها كل الهواتف عتادياً. بدونها قد يعطي يوتيوب صيغة AV1 فيظهر المقطع مشوشاً على أجهزة كثيرة. إطفاؤها يتيح أعلى دقة ممكنة على حساب التوافق.';

  @override
  String get completed => 'مكتمل';

  @override
  String get connectionFailed => 'فشل الاتصال';

  @override
  String get connectionSuccessful => 'تم الاتصال بنجاح — حُفظت الإعدادات';

  @override
  String get continueAsAudio => 'متابعة صوتاً';

  @override
  String get continueAsAudioBody => 'أُتابع تشغيله صوتاً من نفس الثانية؟';

  @override
  String get continueAsAudioNo => 'لا، أوقف';

  @override
  String get continueAsAudioTitle => 'متابعة بالخلفية؟';

  @override
  String get cookies => 'الكوكيز';

  @override
  String get cookiesAbsent => 'السيرفر بلا كوكيز';

  @override
  String get cookiesDelete => 'احذف الكوكيز';

  @override
  String get cookiesDeleteBody =>
      'سيتوقف السيرفر عن استعمالها، والمنصات التي كانت تطلب تسجيل الدخول سترفض من جديد.';

  @override
  String get cookiesDeleted => 'حُذفت الكوكيز من السيرفر';

  @override
  String get cookiesHelp =>
      'من متصفحك، استعمل إضافة تصدّر الكوكيز بصيغة Netscape — ملفاً لكل منصة — ثم اختر الملفات هنا. بعدها يستعملها السيرفر في كل تحميل، وyt-dlp هو من يقرر متى يحتاجها. والكوكيز تنتهي صلاحيتها، فعودة الفشل غالباً تعني أن وقت تصدير جديد قد حان.';

  @override
  String get cookiesNotNetscape =>
      'لا يحوي أيٌّ من هذه الملفات كوكيز بصيغة Netscape';

  @override
  String get cookiesPresent => 'السيرفر لديه كوكيز';

  @override
  String get cookiesPrivacy =>
      'يُرسَل الملف إلى سيرفرك مباشرة ولا يُحفظ على هذا الجوال أبداً. وهو مادة دخولك إلى حساباتك، فلا ترفعه إلا إلى سيرفر تملكه.';

  @override
  String get cookiesReplace => 'استبدل ملفات الكوكيز';

  @override
  String get cookiesReplaceNote =>
      'كل رفع يستبدل ملف الكوكيز على السيرفر كله. لتبقى عدة منصات، اختر ملفاتها كلها معاً في كل مرة — حتى التي رفعتها قبل. للاختيار المتعدد: اضغط مطوّلاً على أول ملف.';

  @override
  String cookiesSentFor(String sites) {
    return 'أُرسلت كوكيز: $sites';
  }

  @override
  String get cookiesSubtitle => 'للمنصات التي ترفض التحميل بلا تسجيل دخول';

  @override
  String get cookiesTooLarge =>
      'هذا الملف أكبر من ميغابايت واحد، وهو أكثر مما يقبله السيرفر.';

  @override
  String get cookiesUnknown =>
      'نسخة MeTube هذه لا تستطيع إخبارك إن كان لديها كوكيز';

  @override
  String get cookiesUpload => 'اختر ملفات الكوكيز';

  @override
  String get cookiesUploaded => 'أُرسلت الكوكيز إلى السيرفر';

  @override
  String get cookiesWhat =>
      'بعض المنصات ترفض تسليم المقطع ما لم يبدُ الطلب قادماً من متصفح مسجَّل الدخول. وملف كوكيز مصدَّر من متصفحك يعطي السيرفر ذلك.';

  @override
  String get copiedToClipboard => 'نُسِخ إلى الحافظة';

  @override
  String get copyright => '© 2026 ياسر صغير';

  @override
  String get couldNotLoadPlaylist =>
      'تعذّر تحميل هذه القائمة. تحقّق من الرابط واتصالك.';

  @override
  String get create => 'إنشاء';

  @override
  String get createPlaylist => 'إنشاء قائمة';

  @override
  String get creator => 'المنشئ';

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
    return 'حذف $count فيديو؟\n\nسيتم إزالة الملفات من جهازك.';
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
    return 'حذف «$title»؟\n\nسيؤدي هذا إلى إزالة الملف من جهازك.';
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
      'عرض السجلّات والبحث فيها ومشاركتها (مُنقّحة)';

  @override
  String get disclaimer => 'اخلاء مسؤولية';

  @override
  String get disclaimerText =>
      'هذا التطبيق هو عميل لسيرفر MeTube. المطور غير مسؤول عن طريقة استخدام هذه الاداة. يرجى احترام حقوق الملكية الفكرية وشروط خدمة منصات المحتوى.';

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
  String get downloading => 'جاري التحميل...';

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
  String get endpointUrl => 'عنوان نقطة النهاية';

  @override
  String get enterFullscreen => 'ملء الشاشة';

  @override
  String get errAuth => 'اسم المستخدم أو كلمة المرور خاطئة';

  @override
  String get errNetwork => 'تعذر الوصول للسيرفر';

  @override
  String get errNoApi => 'العنوان يستجيب لكن لا يوجد MeTube API عليه';

  @override
  String get errNotMeTube => 'هذا العنوان ليس سيرفر MeTube';

  @override
  String get errPlatformBlocked =>
      'المنصة تطلب تسجيل الدخول — على مدير السيرفر تحديث الكوكيز';

  @override
  String get errPlatformBlockedCookies =>
      'المنصة تطلب تسجيل الدخول — ارفع ملف كوكيز من الإعدادات ← الكوكيز';

  @override
  String get errPollTimeout => 'طال انتظار السيرفر — أعد المحاولة';

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
      'عندما يتعذّر الوصول للعنوان المحلي، يتصل التطبيق بأول عنوان يمكن الوصول إليه أدناه، من الأعلى إلى الأسفل.';

  @override
  String get externalNetworkSection => 'شبكة خارجية';

  @override
  String get externalPlayerShort => 'مشغل خارجي';

  @override
  String get failed => 'فشل';

  @override
  String get failedToLoadPlaylist => 'فشل تحميل القائمة';

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
  String get helpAboutField => 'حول هذا الحقل';

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
      other: '$count مقطعاً معروفاً',
      few: '$count مقاطع معروفة',
      two: 'مقطعان معروفان',
      one: 'مقطع معروف',
      zero: 'لا مقاطع معروفة',
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
  String get licenses => 'تراخيص المصادر المفتوحة';

  @override
  String get listSeparator => '، ';

  @override
  String get listenInBackground => 'استماع بالخلفية';

  @override
  String get localCopyRemoved => 'أُزيلت النسخة المحلية';

  @override
  String get localNetworkDesc =>
      'سيتصل التطبيق بالخادم عبر هذا العنوان عند إمكانية الوصول إليه.';

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
      'تُحذف الروابط والعناوين والاعتمادات قبل المشاركة';

  @override
  String get madeOffline => 'أُتيح دون اتصال';

  @override
  String get makeOffline => 'إتاحة دون اتصال';

  @override
  String get manageTags => 'إدارة الوسوم';

  @override
  String get mediaAccessBlockedMessage =>
      'لن يسأل أندرويد مرة أخرى. فعّل «الصور ومقاطع الفيديو» لهذا التطبيق من إعدادات النظام ثم ارجع.';

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
  String get modeStopAtEnd => 'إيقاف عند النهاية';

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
  String get neverChecked => 'لم تُفحص بعد';

  @override
  String newFromSubscriptions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مقطعاً جديداً من قنواتك',
      few: '$count مقاطع جديدة من قنواتك',
      two: 'جديدان من قنواتك',
      one: 'جديد من قناة تتابعها',
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
      'ستظهر الفيديوهات المحملة هنا.\nشارك رابط فيديو أو استخدم زر إضافة رابط.';

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
  String get noTagsYet => 'لا وسوم بعد. أنشئ واحداً بالأسفل.';

  @override
  String get noVideosFound => 'مكتبتك فارغة';

  @override
  String get noWarranty => 'يُقدَّم كما هو، بلا أي ضمان.';

  @override
  String get notAffiliated =>
      'عميل غير رسمي — لا يتبع مشروع MeTube ولا yt-dlp ولا يمثّلهما.';

  @override
  String get nothingHereYet => 'لا يوجد شيء بعد';

  @override
  String get notifyArrivals => 'أخبرني بما يصل وحده';

  @override
  String get notifyArrivalsDesc =>
      'إشعار واحد حين تنزل مقاطع قناة تتابعها على السيرفر. يظهر حين تفتح التطبيق أو تعود إليه أو تحدّث المكتبة، لا والتطبيق في الخلفية.';

  @override
  String get nowPlaying => 'قيد التشغيل';

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
      'لا يُنزَّل إلا ما يُنشر من الآن. أما مقاطع القناة الموجودة فتُترك مكانها.';

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
  String get playingFromDevice => 'تشغيل من جهازك';

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
  String get pullingToDevice => 'يُسحب للجهاز…';

  @override
  String pullingToDeviceProgress(Object percent) {
    return 'يُسحب للجهاز · $percent٪';
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
      'تُستعمل في التحميل السريع، وفي تحميل قائمة كاملة، وفي «حمّل الآن» من شريط الحافظة — وتكون الخيار المُنتقى مسبقاً في نافذة إضافة الرابط. فهي مفيدة سواء كان التحميل السريع مفعَّلاً أم لا.';

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
      'الرابط المشارَك أو الملصوق يبدأ التحميل فوراً بالجودة الافتراضية بلا نافذة. الجودات الرقمية ليوتيوب وحده — غيره ينزل بأفضل جودة، وإن كانت الجودة الافتراضية «صوت فقط» فهي تُطبَّق على كل المنصات.';

  @override
  String get reelsEndBack => 'عودة للمكتبة';

  @override
  String get reelsEndContinue => 'متابعة بقية القائمة';

  @override
  String get reelsEndReplay => 'أعد من البداية';

  @override
  String get reelsEndTitle => 'انتهى مسار القِصار';

  @override
  String get reelsSwipeHint => 'اسحب لأعلى للمقطع التالي';

  @override
  String get refresh => 'تحديث';

  @override
  String get remove => 'إزالة';

  @override
  String get removeFromFavorites => 'أزل من المفضلة';

  @override
  String get removeLocalCopy => 'إزالة النسخة المحلية';

  @override
  String removeUnavailable(int count) {
    return 'إزالة $count غير متوفر';
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
  String get reportBug => 'الابلاغ عن مشكلة';

  @override
  String get restoreConfirm =>
      'استعادة البيانات من ملف النسخة الاحتياطية؟ سيُستبدل ما لديك من قوائم ووسوم وإعدادات.';

  @override
  String get restoreData => 'استعادة';

  @override
  String get restoreFailed => 'فشلت الاستعادة — ملف نسخة غير صالح';

  @override
  String get restoreSettings => 'استعادة جميع البيانات';

  @override
  String get restoreSuccess => 'تمت استعادة البيانات بنجاح';

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
  String get saveToDevice => 'حفظ للجهاز';

  @override
  String get savedOnDevice => 'محفوظ للجهاز';

  @override
  String get searchLogs => 'بحث في السجلّات…';

  @override
  String get searchVideos => 'بحث في الفيديوهات...';

  @override
  String get seekBackward10 => 'إرجاع ١٠ ثوانٍ';

  @override
  String get seekForward10 => 'تقديم ١٠ ثوانٍ';

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
      'يُحذف سجل العنصر ويبقى الملف على القرص، فيمتلئ الخادم. اضبط DELETE_FILE_ON_TRASHCAN=true على حاوية MeTube.';

  @override
  String get serverKeepsFilesTitle => 'خادمك لا يحذف الملفات';

  @override
  String serverQueueCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count في الطابور',
      few: '$count في الطابور',
      two: 'اثنان في الطابور',
      one: 'واحد في الطابور',
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
      'المقاطع المحفوظة على هاتفك ما زالت تعمل.';

  @override
  String get serverUrl => 'رابط السيرفر (MeTube)';

  @override
  String get serverUrlHelpBody =>
      'عنوان خادم MeTube، مثل http://192.168.1.10:8081. استخدم عنوان IP المحلي لـ HTTP العادي في المنزل، أو عنوان HTTPS (مثل Cloudflare Tunnel) للوصول من الخارج.';

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
  String get serverVersionUnknown => 'النسخة غير معروفة';

  @override
  String get settings => 'الإعدادات';

  @override
  String get settingsSaved => 'تم حفظ الإعدادات بنجاح';

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
    return 'كل ما جاء من $channel';
  }

  @override
  String get shuffle => 'تبديل عشوائي';

  @override
  String get signInRequired => 'يلزم تسجيل الدخول';

  @override
  String get signInRequiredHint =>
      'رفض السيرفر الاعتماد المحفوظ. حدّث اسم المستخدم وكلمة المرور في الإعدادات.';

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
  String get sortedByLastPlayed => 'بآخر تشغيل';

  @override
  String get source => 'المصدر';

  @override
  String get sourceCode => 'الشيفرة المصدرية';

  @override
  String get startDownload => 'ابدأ التحميل';

  @override
  String get status => 'الحالة';

  @override
  String get streamingFromServer => 'بث مباشر من السيرفر';

  @override
  String subscriptionAdded(String name) {
    return 'تتابع الآن $name';
  }

  @override
  String get subscriptionName => 'الاسم';

  @override
  String get subscriptionPaused => 'موقوفة مؤقتاً';

  @override
  String get subscriptionQuality => 'جودة هذه القناة';

  @override
  String get subscriptionQualityHelp =>
      'السيرفر يحفظ الجودة لحظة المتابعة ولا يسمح بتغييرها. لتغييرها: افحص الآن، ثم ألغِ المتابعة وتابع من جديد.\n\n«الأفضل» قد يأتي بدقة 4K بترميز AV1. الجوالات الحديثة تشغّله بسلاسة، فإن رأيت تقطيعاً فجوالك لا يفكّه بالعتاد: اختر 1080p، أو فعّل «أفضل توافق للتشغيل» قبل المتابعة.';

  @override
  String get subscriptionQualityNote => 'لا تُغيَّر بعد المتابعة.';

  @override
  String get subscriptions => 'الاشتراكات';

  @override
  String get subscriptionsEmpty => 'لا قنوات متابَعة بعد';

  @override
  String get subscriptionsEmptyBody =>
      'تابِع قناة، وينزّل السيرفر كل مقطع جديد فيها وحده ويصل مكتبتك مباشرة. وما هو منشور عليها الآن يبقى مكانه.';

  @override
  String get subscriptionsSubtitle => 'قنوات يتابعها السيرفر نيابةً عنك';

  @override
  String get subscriptionsUnsupported => 'نسخة MeTube لديك أقدم من الاشتراكات';

  @override
  String get subscriptionsUnsupportedBody =>
      'حدّث حاوية MeTube إلى إصدار فيه اشتراكات القنوات ثم عد إلى هنا. لا شيء آخر في التطبيق يتأثر.';

  @override
  String get tagActionsHint => 'اضغط مطوّلاً على وسم لإعادة تسميته أو حذفه.';

  @override
  String get tags => 'الوسوم';

  @override
  String get tagsOpenFiltered => 'تفتح المكتبة مصفّاة';

  @override
  String get testingConnection => 'جارٍ اختبار الاتصال…';

  @override
  String get theme => 'السمة';

  @override
  String get themeDark => 'داكن';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeSystem => 'النظام';

  @override
  String get titleFilter => 'نزّل فقط ما يحوي عنوانه';

  @override
  String get titleFilterHelp =>
      'لا ينزّل السيرفر مقطعاً جديداً من هذه القناة إلا إذا احتوى عنوانه على ما تكتبه هنا.\n\n• كلمة عادية تكفي: الحلقة\n• أيّ كلمة من عدة كلمات: الحلقة|الجزء — العلامة | تعني «أو»\n• الإنجليزية حساسة لحالة الأحرف: episode لا تطابق Episode. اكتب ‎[Ee]pisode‎ أو الكلمتين.\n\nالمقطع الذي يتجاهله الفلتر يُعدّ مُشاهَداً نهائياً: إزالة الفلتر لاحقاً تُنزّل ما يأتي بعدها، لا ما تجاهله.';

  @override
  String get titleFilterHelper =>
      'عدة كلمات: افصل بينها بـ | . اتركه فارغاً لكل شيء.';

  @override
  String get titleFilterHint => 'مثال: الحلقة';

  @override
  String get titleLabel => 'العنوان';

  @override
  String totalDuration(Object duration) {
    return 'الإجمالي: $duration';
  }

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
      'سينسى السيرفر ما رآه من مقاطع هذه القناة. وإن تابعتها لاحقاً عُدَّ كل الموجود عليها حينها مرئياً، فلا يُسدّ ما فاتك. والإيقاف المؤقت يحفظ هذه الذاكرة.';

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
      'يطلب أندرويد إذنك قبل أن يثبّت التطبيق تحديثاته بنفسه. امنحه مرة واحدة من إعدادات النظام ثم عد واضغط تثبيت.';

  @override
  String get updateAllowInstallTitle => 'السماح بتثبيت التحديثات';

  @override
  String get updateAvailable => 'يتوفّر تحديث';

  @override
  String get updateCheckFailed => 'تعذّر التحقق من التحديثات';

  @override
  String get updateChecking => 'جارٍ التحقق…';

  @override
  String get updateCredentials => 'تحديث الاعتماد';

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
    return '$size م.ب';
  }

  @override
  String get updateSkipVersion => 'تخطّي هذا الإصدار';

  @override
  String get updateUpToDate => 'أنت على أحدث إصدار';

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
  String get wifiOnly => 'التحميل عبر Wi‑Fi فقط';

  @override
  String get wifiOnlyHelp =>
      'يمنع سحب الملفات إلى جهازك على بيانات الجوّال. المهام تنتظر وتُستأنف تلقائياً عند اتصال Wi‑Fi.';

  @override
  String get yourPlaylists => 'قوائمك';

  @override
  String get yourTags => 'وسومك';

  @override
  String get ytdlpCredit => 'أداة التنزيل التي يشغّلها MeTube';
}
