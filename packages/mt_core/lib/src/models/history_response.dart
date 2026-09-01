import 'history_item.dart';

/// استجابة `GET /history` كاملة: `{done, queue, pending}` — القوائم الغائبة
/// تصبح فارغة، والعناصر غير الصالحة تُتجاوز بصمت (تحليل متسامح).
class HistoryResponse {
  const HistoryResponse({
    this.done = const [],
    this.queue = const [],
    this.pending = const [],
  });

  final List<HistoryItem> done;
  final List<HistoryItem> queue;
  final List<HistoryItem> pending;

  /// كل الجاري (queue + pending) — للعرض الحي وبطاقات التقدم.
  List<HistoryItem> get active => [...queue, ...pending];

  bool get isEmpty => done.isEmpty && queue.isEmpty && pending.isEmpty;

  /// صحة الاستكشاف (§2.1): Map يحوي `done` و`queue` معاً — وإلا فليس
  /// سيرفر MeTube (استجابة HTML مثلاً).
  static bool looksLikeMeTube(dynamic decoded) =>
      decoded is Map && decoded.containsKey('done') && decoded.containsKey('queue');

  factory HistoryResponse.fromJson(Map<String, dynamic> json) =>
      HistoryResponse(
        done: _items(json['done']),
        queue: _items(json['queue']),
        pending: _items(json['pending']),
      );

  static List<HistoryItem> _items(dynamic list) {
    if (list is! List) return const [];
    return [
      for (final entry in list)
        if (entry is Map)
          HistoryItem.fromJson(Map<String, dynamic>.from(entry)),
    ];
  }
}
