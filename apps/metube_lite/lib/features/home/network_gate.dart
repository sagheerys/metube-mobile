import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';

import '../../di.dart';

/// The current network state, **synchronously**.
///
/// The engine in mt_core asks the pull gate before fetching any file, and
/// the question is synchronous on purpose: reading state must not
/// introduce a wait into a critical path. So we hold a snapshot kept
/// up to date from `connectivity_plus` rather than querying on every call.
class NetworkGate {
  NetworkGate({Stream<List<ConnectivityResult>>? changes})
    : _changes = changes ?? Connectivity().onConnectivityChanged;

  final Stream<List<ConnectivityResult>> _changes;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  final _restored = StreamController<void>.broadcast();

  // **Pessimistic before the first reading (fix م-11):** starting
  // optimistically at "Wi-Fi" let a pull start on **mobile data** in the
  // first moments of startup, before the first snapshot arrived, which is
  // exactly what the "Wi-Fi only" setting exists to prevent.
  bool _online = true;
  bool _onWifi = false;
  bool _known = false;

  bool get online => _online;
  bool get onWifi => _onWifi;

  /// Has a real snapshot arrived from the system yet?
  bool get isKnown => _known;

  /// Broadcast on the **transition** from disconnected to connected, not on
  /// every network event.
  Stream<void> get onRestored => _restored.stream;

  Future<void> start() async {
    _apply(await Connectivity().checkConnectivity());
    _sub = _changes.listen(_apply);
  }

  void _apply(List<ConnectivityResult> results) {
    final wasOnline = _online;
    _known = true;
    _onWifi =
        results.contains(ConnectivityResult.wifi) ||
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

/// **Retrying when the network returns.**
///
/// Two deliberate decisions:
/// 1. **What the server refused is never retried.**
///    [MTApiException.isRetryable] separates a broken road from a refusal
///    at the destination; repeating a refusal fails and floods the server.
/// 2. **Once per task.** A link that fails twice for network reasons
///    does not have a network problem, and an unbounded retry loop drains
///    the battery and the data plan.
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
      // The old card was retried, so it does not stay on screen as a second
      // failure.
      if (!retried.add(task.inputUrl)) continue;
      engine.submit(task.inputUrl, task.quality);
      // The old card was retried, so it does not stay on screen as a second
      // failure.
      engine.forget(task.id);
    }
  });
  ref.onDispose(sub.cancel);
});
