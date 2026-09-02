import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';

/// حالة الشبكة الحالية بشكل **متزامن**.
///
/// المحرك في mt_core يسأل بوابة السحب قبل جلب أي ملف، والسؤال متزامن
/// عمداً: قراءة الحالة يجب ألا تُدخل انتظاراً في مسار حرج. لذلك نحتفظ
/// بلقطة محدَّثة من `connectivity_plus` بدل الاستعلام عند كل نداء.
class NetworkGate {
  NetworkGate({Stream<List<ConnectivityResult>>? changes})
      : _changes = changes ?? Connectivity().onConnectivityChanged;

  final Stream<List<ConnectivityResult>> _changes;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  final _restored = StreamController<void>.broadcast();

  // **متشائمة قبل أول قراءة (إصلاح م-11):** البدء بـ«واي-فاي» متفائلاً
  // كان يسمح لسحبة أن تنطلق على **بيانات الجوال** في أول لحظات الإقلاع
  // قبل وصول أول لقطة — وهو بالضبط ما جاء إعداد «Wi‑Fi فقط» ليمنعه.
  bool _online = true;
  bool _onWifi = false;
  bool _known = false;

  bool get online => _online;
  bool get onWifi => _onWifi;

  /// هل وصلت لقطة حقيقية من النظام بعد؟
  bool get isKnown => _known;

  /// يُبثّ عند **الانتقال** من انقطاع إلى اتصال — لا مع كل حدث شبكة.
  Stream<void> get onRestored => _restored.stream;

  Future<void> start() async {
    _apply(await Connectivity().checkConnectivity());
    _sub = _changes.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results) {
    final wasOnline = _online;
    _known = true;
    _onWifi = results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.ethernet);
    _online = results.any((r) => r != ConnectivityResult.none);
    if (!wasOnline && _online && !_restored.isClosed) _restored.add(null);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _restored.close();
  }
}

final networkGateProvider = Provider<NetworkGate>((ref) {
  final gate = NetworkGate();
  unawaited(gate.start());
  ref.onDispose(() => unawaited(gate.dispose()));
  return gate;
});

/// **م-43: إعادة المحاولة عند عودة الشبكة.**
///
/// قراران مقصودان:
/// 1. **ما رفضه الخادم لا يُعاد** — [MTApiException.isRetryable] يفرّق
///    بين عطل الطريق ورفض الوجهة؛ إعادة الرفض تفشل وتُغرق السيرفر.
/// 2. **مرة واحدة لكل مهمة** — الرابط الذي يفشل شبكياً مرتين مشكلته
///    ليست الشبكة، وحلقة إعادة بلا سقف تستنزف البطارية والبيانات.
final autoRetryProvider = Provider<void>((ref) {
  final gate = ref.watch(networkGateProvider);
  final retried = <String>{};
  final sub = gate.onRestored.listen((_) {
    if (!ref.read(settingsProvider).autoRetry) return;
    final engine = ref.read(downloadEngineProvider);
    if (engine == null) return;
    for (final task in engine.tasks) {
      if (task.phase != TaskPhase.failed) continue;
      if (!(task.error?.isRetryable ?? false)) continue;
      // **المفتاح هو الرابط لا معرّف المهمة (إصلاح م-4).** المهمة
      // الجديدة تحمل معرفاً جديداً، فكان الرابط نفسه يُعاد عند كل
      // تقلب شبكة، وتتراكم خلفه بطاقات فشل قديمة لا تختفي.
      if (!retried.add(task.inputUrl)) continue;
      engine.submit(task.inputUrl, task.quality);
      // البطاقة القديمة أُعيدت ⇒ لا تبقى معروضة فشلاً ثانياً.
      engine.forget(task.id);
    }
  });
  ref.onDispose(sub.cancel);
});
