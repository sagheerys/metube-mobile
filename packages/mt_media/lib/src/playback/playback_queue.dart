import 'dart:math';

import '../models/play_mode.dart';
import '../models/playlist_item.dart';

/// The play queue: **pure logic with no Flutter and no player**, so it can
/// be tested on its own (TRD §3.2). It holds the actual order, sequential
/// or shuffled, and the current index, and answers one question: what is
/// the next or previous item in this mode?
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

  /// The play order: a list of indexes into [_items].
  List<int> _order = const [];
  int _cursor = 0;

  List<PlaylistItem> get items => List.unmodifiable(_items);
  int get length => _items.length;
  bool get isEmpty => _items.isEmpty;
  bool get shuffle => _shuffle;

  /// The current item's index inside [items], not inside the play order.
  int get index => _order.isEmpty ? -1 : _order[_cursor];

  PlaylistItem? get current => index < 0 ? null : _items[index];

  /// The items in actual play order, for showing "up next" in the queue
  /// sheet.
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
    // Shuffle always starts from the current item and shuffles the rest.
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

  /// The next index according to [mode]. [userInitiated] means the "next"
  /// button was pressed, and then the user is not trapped in repeat-one.
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

  /// Moves the cursor to an index inside [items]; returns false when it is
  /// out of range.
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

  /// Removes an item, skipping a broken one or removing it from the sheet,
  /// keeping the current one where possible. Returns false when the index
  /// is
  /// out of range.
  bool removeAt(int itemIndex) {
    if (itemIndex < 0 || itemIndex >= _items.length) return false;
    final currentItem = index == itemIndex ? null : current;
    _items.removeAt(itemIndex);
    if (_items.isEmpty) {
      _order = const [];
      _cursor = 0;
      return true;
    }
    // The new cursor: the same item if it survived, otherwise whatever took
    // the removed one's place.
    final fallback = itemIndex.clamp(0, _items.length - 1);
    final target =
        currentItem == null ? fallback : _items.indexOf(currentItem);
    _rebuildOrderPreservingShuffle(startAt: target < 0 ? fallback : target);
    return true;
  }

  /// Rebuilds after the items change. Shuffle is reshuffled, since an order
  /// pointing at vanished indexes cannot be preserved, and sequential keeps
  /// its position.
  void _rebuildOrderPreservingShuffle({required int startAt}) =>
      _rebuildOrder(startAt: startAt.clamp(0, _items.length - 1));
}
