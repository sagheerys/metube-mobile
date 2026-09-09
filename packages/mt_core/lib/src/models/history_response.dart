import 'history_item.dart';

/// The complete `GET /history` response: `{done, queue, pending}`. Missing
/// lists become empty, and invalid items are skipped silently (tolerant
/// parsing).
class HistoryResponse {
  const HistoryResponse({
    this.done = const [],
    this.queue = const [],
    this.pending = const [],
  });

  final List<HistoryItem> done;
  final List<HistoryItem> queue;
  final List<HistoryItem> pending;

  /// Everything in flight (queue plus pending), for the live view and the
  /// progress cards.
  List<HistoryItem> get active => [...queue, ...pending];

  bool get isEmpty => done.isEmpty && queue.isEmpty && pending.isEmpty;

  /// The discovery check (§2.1): a map carrying both `done` and `queue`.
  /// Anything else is not a MeTube server, an HTML response for example.
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
