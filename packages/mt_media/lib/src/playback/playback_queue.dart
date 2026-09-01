import 'dart:math';

import '../models/play_mode.dart';
import '../models/playlist_item.dart';

/// طابور التشغيل — **منطق خالص بلا Flutter ولا مشغل** ليُختبر وحده
/// (TRD §3.2). يحمل الترتيب الفعلي (عادي أو عشوائي) والمؤشر الحالي،
/// ويجيب على سؤال واحد: ما العنصر التالي/السابق بهذا الوضع؟
class PlaybackQueue {
  PlaybackQueue({
    required List<PlaylistItem> items,
    int index = 0,
    bool shuffle = false,
    Random? random,
  })  : _items = List.of(items),
        _random = random ?? Random() {
    _shuffle = shuffle;
    final start = _items.isEmpty ? 0 : index.clamp(0, _items.length - 1);
    _rebuildOrder(startAt: start);
  }

  final List<PlaylistItem> _items;
  final Random _random;
  late bool _shuffle;

  /// ترتيب التشغيل: قائمة فهارس داخل [_items].
  List<int> _order = const [];
  int _cursor = 0;

  List<PlaylistItem> get items => List.unmodifiable(_items);
  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get shuffle => _shuffle;

  /// فهرس العنصر الحالي داخل [items] (لا داخل ترتيب التشغيل).
  int get index => _order.isEmpty ? -1 : _order[_cursor];

  PlaylistItem? get current => index < 0 ? null : _items[index];

  /// العناصر بترتيب التشغيل الفعلي — لعرض «التالي» في ورقة القائمة.
  List<PlaylistItem> get ordered => [for (final i in _order) _items[i]];

  bool get isLast => _order.isEmpty || _cursor == _order.length - 1;
  bool get isFirst => _cursor == 0;

  void _rebuildOrder({required int startAt}) {
    if (_items.isEmpty) {
      _order = const [];
      _cursor = 0;
      return;
    }
    if (!_shuffle) {
      _order = List.generate(_items.length, (i) => i);
      _cursor = startAt;
      return;
    }
    // العشوائي يبدأ دائماً من العنصر الحالي ثم يخلط الباقي.
    final rest = [
      for (var i = 0; i < _items.length; i++)
        if (i != startAt) i,
    ]..shuffle(_random);
    _order = [startAt, ...rest];
    _cursor = 0;
  }

  void setShuffle(bool value) {
    if (value == _shuffle) return;
    final currentIndex = index < 0 ? 0 : index;
    _shuffle = value;
    _rebuildOrder(startAt: currentIndex);
  }

  /// فهرس التالي بحسب [mode]. [userInitiated] يعني ضغط زر «التالي» —
  /// وقتها لا يُحبس المستخدم في «تكرار واحد».
  int? nextIndex(PlayMode mode, {bool userInitiated = false}) {
    if (_order.isEmpty) return null;
    if (mode == PlayMode.repeatOne && !userInitiated) return index;
    if (_cursor < _order.length - 1) return _order[_cursor + 1];
    final wraps = mode == PlayMode.repeatAll ||
        (userInitiated && mode == PlayMode.repeatOne);
    return wraps ? _order.first : null;
  }

  int? previousIndex(PlayMode mode) {
    if (_order.isEmpty) return null;
    if (_cursor > 0) return _order[_cursor - 1];
    return mode == PlayMode.repeatAll ? _order.last : null;
  }

  /// ينقل المؤشر لفهرس داخل [items]؛ يعيد false إن كان خارج المدى.
  bool jumpTo(int itemIndex) {
    final position = _order.indexOf(itemIndex);
    if (position < 0) return false;
    _cursor = position;
    return true;
  }

  bool moveNext(PlayMode mode, {bool userInitiated = false}) {
    final target = nextIndex(mode, userInitiated: userInitiated);
    return target == null ? false : jumpTo(target);
  }

  bool movePrevious(PlayMode mode) {
    final target = previousIndex(mode);
    return target == null ? false : jumpTo(target);
  }

  /// حذف عنصر (تخطي معطوب أو إزالة من الورقة) مع الحفاظ على الحالي
  /// ما أمكن. يعيد false إن كان الفهرس خارج المدى.
  bool removeAt(int itemIndex) {
    if (itemIndex < 0 || itemIndex >= _items.length) return false;
    final currentItem = index == itemIndex ? null : current;
    _items.removeAt(itemIndex);
    if (_items.isEmpty) {
      _order = const [];
      _cursor = 0;
      return true;
    }
    // المؤشر الجديد: نفس العنصر إن بقي، وإلا الذي حل محل المحذوف.
    final fallback = itemIndex.clamp(0, _items.length - 1);
    final target =
        currentItem == null ? fallback : _items.indexOf(currentItem);
    _rebuildOrderPreservingShuffle(startAt: target < 0 ? fallback : target);
    return true;
  }

  /// إعادة بناء بعد تغيّر العناصر — العشوائي يُخلط من جديد (لا سبيل
  /// لحفظ ترتيب يشير لفهارس اختفت) والعادي يحافظ على موضعه.
  void _rebuildOrderPreservingShuffle({required int startAt}) =>
      _rebuildOrder(startAt: startAt.clamp(0, _items.length - 1));
}
