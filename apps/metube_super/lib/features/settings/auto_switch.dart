import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';
import 'settings_state.dart';

/// **م-28 / ر-9 — التبديل التلقائي الفعلي.**
///
/// خلل مصطاد على جهاز المالك (2026-09-01): كان المنفَّذ هو *العرض*
/// و*التبديل اليدوي* فقط — `connectivity_plus` معلن في الحزم ولا يُستورد
/// في أي ملف، ولا مستمع لتغيّر الشبكة، و`adoptActiveUrl` لا يُستدعى إلا
/// بنقرة في شاشة الشبكة. النتيجة على شبكة المالك المنزلية: الجوال بجانب
/// السيرفر ومع ذلك يبث عبر نفق Cloudflare — **أبطأ ٤١×** بالقياس
/// (2MB: 2.3s محلياً مقابل 94.8s عبر النفق).
///
/// المحفّزات الثلاثة: تغيّر الشبكة (واي-فاي/بيانات/انقطاع)، وعودة
/// التطبيق للمقدمة (الشبكة قد تكون تبدلت والتطبيق بالخلفية)، والإقلاع.
class AutoSwitchService {
  AutoSwitchService(
    this._ref, {
    Stream<Object?>? networkChanges,
    this.debounce = const Duration(milliseconds: 700),
  }) : _changes = networkChanges ?? Connectivity().onConnectivityChanged;

  final Ref _ref;
  final Stream<Object?> _changes;

  /// تغيّر الشبكة يصل **دفعات** (فقد ثم اتصال ثم عنوان) — بلا تهدئة
  /// نطلق ثلاثة فحوص متوازية على نفس الحدث.
  final Duration debounce;

  StreamSubscription<Object?>? _sub;
  AppLifecycleListener? _lifecycle;
  Timer? _timer;
  bool _running = false;
  bool _pending = false;

  /// آخر رابط اعتُمد تلقائياً — لبطاقة الحالة والتشخيص.
  String? lastAdopted;

  void start() {
    _sub = _changes.listen((_) => schedule());
    _lifecycle = AppLifecycleListener(onResume: schedule);
    schedule(immediate: true);
  }

  /// **التهدئة هنا لا في التنفيذ (إصلاح عاصفة ط-6):** استطلاع المكتبة
  /// كل ثانيتين يُبطل `historyProvider`، ومستمع الخطأ كان يجدول فحصاً عند
  /// **كل** إخفاق — وتهدئة 700ms أقصر من الثانيتين فلا تجمع شيئاً:
  /// سيرفر معطّل + شاشة مكتبة مفتوحة = فحص لكل الروابط كل ثانيتين بلا
  /// توقف، بعملاء جدد ومهلة 4s. الآن الفحوص المجدولة تتباعد بـ
  /// [minInterval] على الأقل، والمحفّز الفوري (الإقلاع) وحده يستثنى.
  void schedule({bool immediate = false}) {
    _timer?.cancel();
    if (immediate) {
      _timer = Timer(Duration.zero, () => unawaited(resolveNow()));
      return;
    }
    final since =
        _lastRun == null ? null : DateTime.now().difference(_lastRun!);
    final wait = since == null || since >= minInterval
        ? debounce
        : minInterval - since;
    _timer = Timer(wait, () => unawaited(resolveNow()));
  }

  /// فحص متوازٍ لكل المرشحين واعتماد أولهم استجابةً (المحلي أولاً).
  /// لا يفعل شيئاً إن أُطفئ التبديل أو لم تُسجَّل روابط.
  /// أقل فاصل بين فحصين **مجدولين** — انظر [schedule].
  static const minInterval = Duration(seconds: 20);
  DateTime? _lastRun;

  Future<void> resolveNow() async {
    final settings = _ref.read(settingsProvider);
    if (!settings.autoSwitch) return;
    // **لا تبديل والعمل جارٍ (العطل ع-1):** تبديل الرابط يعيد بناء
    // المحرك فيبيد كل مهامه بصمت. التأجيل حتى يهدأ الطابور أرحم من
    // تحميل ضائع بلا رسالة.
    final engine = _ref.read(downloadEngineProvider);
    if (engine != null && engine.hasActiveWork) {
      // إعادة المحاولة بنفسها — لا مستمع آخر سيوقظنا حين يهدأ الطابور.
      _timer?.cancel();
      _timer = Timer(minInterval, () => unawaited(resolveNow()));
      return;
    }
    _lastRun = DateTime.now();
    final candidates = settings.candidateUrls;
    if (candidates.isEmpty) return;
    // مرشح واحد وهو المعتمد أصلاً ⇒ لا شيء يُبدَّل، ولا داعي لـ probe.
    if (candidates.length == 1 && candidates.first == settings.activeUrl) {
      return;
    }
    // المعتمد **ليس من المرشحين** (حُذف أو عُدّل الرابط) ⇒ نتبنى النتيجة
    // ولو ساوت القديم — وإلا بقي التطبيق معلّقاً على عنوان لا وجود له.
    final activeIsStale = !candidates.contains(settings.activeUrl);
    // فحص جارٍ؟ نؤجل واحداً فقط بدل تكديس الطلبات.
    if (_running) {
      _pending = true;
      return;
    }
    _running = true;
    try {
      final probe = await _ref.read(endpointResolverProvider).resolveDetailed(
            localUrl: settings.localUrl,
            externalUrls: settings.externalUrls,
          );
      final best = probe.url;
      // لا شيء يستجيب ⇒ **نُبقي المعتمد كما هو**: الشبكة قد تكون في
      // منتصف التبديل، وتصفير الرابط يفرّغ المكتبة أمام المستخدم.
      if (best == null) {
        // **السبب يُسجَّل** (بلاغ المالك 2026-09-05): قفل السيرفر
        // بكلاودفلير أوقف التبديل، ولم يكن في السجل ما يميّز «مقفل»
        // عن «مقطوع» — فبدا العطل بلا سبب.
        final locked = probe.statuses.values
            .where((s) => s == MTEndpointStatus.unauthorized)
            .length;
        unawaited(_ref.read(loggerProvider).log(
            locked > 0
                ? 'no usable endpoint — $locked rejected credentials (401)'
                : 'no usable endpoint — none reachable',
            tag: 'network'));
        return;
      }
      if (best == settings.activeUrl && !activeIsStale) return;
      lastAdopted = best;
      // م-32: تبديل السيرفر أهم حدث تشخيصي في Super — وكان لا يُسجَّل.
      unawaited(_ref
          .read(loggerProvider)
          .log('server switched to $best', tag: 'network'));
      await _ref.read(settingsProvider.notifier).adoptActiveUrl(best);
    } finally {
      _running = false;
      if (_pending) {
        _pending = false;
        schedule();
      }
    }
  }

  void dispose() {
    _timer?.cancel();
    _lifecycle?.dispose();
    unawaited(_sub?.cancel());
  }
}

/// يعمل طوال عمر التطبيق — يُراقَب من [SuperApp] لا من شاشة.
final autoSwitchProvider = Provider<AutoSwitchService>((ref) {
  final service = AutoSwitchService(ref)..start();

  // **محفّز رابع مصطاد على الجهاز:** تعديل قائمة الروابط لم يكن يُطلق
  // فحصاً، فبقي التطبيق معلّقاً على عنوان لم يعد مسجّلاً أصلاً.
  ref.listen<(String, String, bool)>(
    settingsProvider.select(
      (s) => (s.localUrl, s.externalUrls.join('|'), s.autoSwitch),
    ),
    (_, _) => service.schedule(),
  );

  // **محفّز خامس:** فشل نداء السيرفر. لا كل انقطاع يرافقه حدث شبكة —
  // السيرفر قد يُعاد تشغيله، أو ينتقل الجوال بين نقطتي وصول بلا مسار
  // للـ LAN. الفشل نفسه هو الإشارة الوحيدة عندئذٍ.
  ref.listen(historyProvider, (_, next) {
    if (next.hasError) service.schedule();
  });

  ref.onDispose(service.dispose);
  return service;
});

/// **بذرة قائمة الروابط.** التثبيت القديم (والإعداد ر-1) يكتب `server_url`
/// وحده، فتبقى قائمة م-28 فارغة و«التبديل التلقائي» بلا مرشحين — يظهر
/// مفعّلاً ولا يبدّل شيئاً. هنا نصنّف الرابط المهيّأ مرة واحدة: عنوان
/// شبكة خاصة ⇒ «المحلي»، وغيره ⇒ أول رابط خارجي.
Future<void> seedEndpointsFromActive(
  KeyValueStore store,
  PrefsMutex mutex,
  SuperSettings settings,
) async {
  final active = (settings.activeUrl ?? '').trim();
  if (active.isEmpty) return;
  if (settings.localUrl.trim().isNotEmpty ||
      settings.externalUrls.isNotEmpty) {
    return;
  }
  await mutex.run(() async {
    if (isPrivateHostUrl(active)) {
      await store.setString('local_url', active);
    } else {
      await store.setStringList('external_urls', [active]);
    }
  });
}

/// عنوان على شبكة محلية؟ (`10.x`، `192.168.x`، `172.16–31.x`، `127.x`،
/// `*.local`، اسم بلا نقطة). يُستعمل لتصنيف الرابط المهيّأ وحده.
bool isPrivateHostUrl(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  if (host.isEmpty) return false;
  if (host == 'localhost' || host.endsWith('.local')) return true;
  if (!host.contains('.')) return true;
  final octets = host.split('.');
  if (octets.length != 4) return false;
  final n = octets.map(int.tryParse).toList();
  if (n.any((v) => v == null || v < 0 || v > 255)) return false;
  return switch (n[0]!) {
    10 || 127 => true,
    192 => n[1] == 168,
    172 => n[1]! >= 16 && n[1]! <= 31,
    _ => false,
  };
}
