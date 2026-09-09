import 'dart:async';

import '../models/history_item.dart';

/// Parking tasks the network gate stopped.
///
/// The single worker used to stall on a task held by "Wi-Fi only" at the
/// head of the queue, so everything behind it stopped even being *added*
/// to the server and simply showed "waiting" with no explanation. Now such
/// a task is parked aside with its history item ready, the queue
/// continues, and a periodic tick wakes it when the gate allows.
class PullGateParking {
  PullGateParking({required this.pollInterval, required this.onWake});

  final Duration pollInterval;
  final void Function() onWake;

  final Map<String, HistoryItem> _items = {};
  Timer? _ticker;

  bool get isEmpty => _items.isEmpty;
  bool get isNotEmpty => _items.isNotEmpty;

  void park(String taskId, HistoryItem done) {
    _items[taskId] = done;
    _ticker ??= Timer.periodic(pollInterval, (_) {
      if (_items.isEmpty) return _stop();
      onWake();
    });
  }

  /// The first parked task if [gate] allows. It is removed before it runs,
  /// so it can never run twice.
  (String, HistoryItem)? takeIfOpen(bool Function() gate) {
    if (_items.isEmpty || !gate()) return null;
    final id = _items.keys.first;
    final item = _items.remove(id)!;
    if (_items.isEmpty) _stop();
    return (id, item);
  }

  bool remove(String taskId) {
    final removed = _items.remove(taskId) != null;
    if (_items.isEmpty) _stop();
    return removed;
  }

  void clear() {
    _items.clear();
    _stop();
  }

  void _stop() {
    _ticker?.cancel();
    _ticker = null;
  }
}
