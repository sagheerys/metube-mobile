/// طابور التحميل (§3): تزامن أقصاه 1 (حماية السيرفر) يفرضه المحرك،
/// وهنا الترتيب فقط — **المفرد يتقدم على أعضاء الدفعات**، وداخل كل صنف
/// FIFO بترتيب الإضافة.
class DownloadQueue {
  final List<String> _singles = [];
  final List<String> _batchMembers = [];

  void enqueue(String taskId, {required bool isBatchMember}) {
    (isBatchMember ? _batchMembers : _singles).add(taskId);
  }

  /// التالي للتنفيذ أو null إن فرغ الطابور.
  String? takeNext() {
    if (_singles.isNotEmpty) return _singles.removeAt(0);
    if (_batchMembers.isNotEmpty) return _batchMembers.removeAt(0);
    return null;
  }

  /// إزالة مهمة لم تبدأ بعد (إلغاء وهي منتظرة).
  bool remove(String taskId) =>
      _singles.remove(taskId) || _batchMembers.remove(taskId);

  bool get isEmpty => _singles.isEmpty && _batchMembers.isEmpty;
  int get length => _singles.length + _batchMembers.length;

  /// المعرفات المنتظرة بترتيب التنفيذ المتوقع.
  List<String> get pendingIds => [..._singles, ..._batchMembers];
}
