import 'dart:async';

import '../models/history_item.dart';

/// ركن المهام التي أوقفتها بوابة الشبكة (م-42) — **إصلاح م-10**.
///
/// كان العامل الواحد يقف على مهمة محجوزة بـ«Wi‑Fi فقط» في رأس الطابور،
/// فتتوقف حتى *إضافة* ما بعدها إلى السيرفر وتظهر «في الانتظار» بلا
/// تفسير. الآن تُركن جانباً بعنصر سجلها جاهزاً، ويكمل الطابور، ويوقظها
/// نبض دوري حين تأذن البوابة.
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

  /// أول مهمة مركونة إن أذنت [gate] — تُنزع قبل تشغيلها فلا تُشغَّل مرتين.
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
