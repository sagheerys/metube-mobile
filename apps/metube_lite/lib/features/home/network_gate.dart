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

  bool _online = true;
  bool _onWifi = true;

  bool get online => _online;
  bool get onWifi => _onWifi;

  /// يُبثّ عند **الانتقال** من انقطاع إلى اتصال — لا مع كل حدث شبكة.
  Stream<void> get onRestored => _restored.stream;

  Future<void> start() async {
    _apply(await Connectivity().checkConnectivity());
    _sub = _changes.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results) {
    final wasOnline = _online;
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
      if (!retried.add(task.id)) continue;
      engine.submit(task.inputUrl, task.quality);
    }
  });
  ref.onDispose(sub.cancel);
});
