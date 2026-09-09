/// The download queue (§3). Concurrency of at most 1, to protect the
/// server, is enforced by the engine; only ordering lives here. **A single
/// item outranks members of a batch**, and within each class it is FIFO by
/// add order.
class DownloadQueue {
  final List<String> _singles = [];
  final List<String> _batchMembers = [];

  void enqueue(String taskId, {required bool isBatchMember}) {
    (isBatchMember ? _batchMembers : _singles).add(taskId);
  }

  /// The next task to run, or null when the queue is empty.
  String? takeNext() {
    if (_singles.isNotEmpty) return _singles.removeAt(0);
    if (_batchMembers.isNotEmpty) return _batchMembers.removeAt(0);
    return null;
  }

  /// Removes a task that has not started yet, when it is cancelled while
  /// waiting.
  bool remove(String taskId) =>
      _singles.remove(taskId) || _batchMembers.remove(taskId);

  bool get isEmpty => _singles.isEmpty && _batchMembers.isEmpty;
  int get length => _singles.length + _batchMembers.length;

  /// The waiting ids in their expected execution order.
  List<String> get pendingIds => [..._singles, ..._batchMembers];
}
