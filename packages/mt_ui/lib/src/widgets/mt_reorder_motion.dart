import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';
import 'mt_polish.dart';

/// **A column whose rows travel to their new place** when the order
/// changes, instead of jumping there.
///
/// A list sorted by state, such as subscriptions with the paused ones last,
/// moves a row the moment its state changes: the row the user just touched
/// disappeared from under the finger and turned up somewhere else, with
/// nothing saying where (field report 2026-10-04). Each row now slides from
/// where it was to where it belongs, so the eye follows it.
///
/// Every child needs a key that stays with it across orders. A row that is
/// new, or whose old place is unknown, simply appears. When the system asks
/// to reduce motion, the rows move without travelling.
class MTReorderMotion extends StatefulWidget {
  const MTReorderMotion({super.key, required this.children});

  final List<Widget> children;

  @override
  State<MTReorderMotion> createState() => _MTReorderMotionState();
}

class _MTReorderMotionState extends State<MTReorderMotion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _travel = AnimationController(vsync: this);

  /// Measured after every layout: where each row's top was, and how tall
  /// it was, in this column's own coordinates.
  final Map<Key, GlobalKey> _boxes = {};
  Map<Key, double> _tops = {};
  Map<Key, double> _heights = {};

  /// How far each moving row starts from its new place.
  Map<Key, double> _from = {};

  List<Key> _keysOf(List<Widget> children) => [
    for (final child in children) child.key!,
  ];

  /// Where a row is drawn right now: its laid-out top, plus whatever is
  /// left of a travel still under way.
  double? _visibleTop(Key key) {
    final top = _tops[key];
    if (top == null) return null;
    final from = _from[key] ?? 0;
    return top + from * (1 - MTMotion.ease.transform(_travel.value));
  }

  @override
  void didUpdateWidget(MTReorderMotion old) {
    super.didUpdateWidget(old);
    final before = _keysOf(old.children);
    final after = _keysOf(widget.children);
    if (listEquals(before, after)) return;
    // The new places are predicted from the heights already measured, so
    // the very first frame draws each row where it was, not where it is
    // going: waiting for the next layout would flash the end state.
    final from = <Key, double>{};
    var y = 0.0;
    for (final key in after) {
      final height = _heights[key];
      final was = _visibleTop(key);
      if (height == null) {
        // A row never measured: the places after it cannot be predicted.
        break;
      }
      if (was != null && (was - y).abs() > 0.5) from[key] = was - y;
      y += height;
    }
    _from = from;
    if (from.isEmpty) return;
    _travel
      ..duration = mtMotionDuration(context, MTMotion.medium)
      ..forward(from: 0);
  }

  void _measure() {
    if (!mounted) return;
    final column = context.findRenderObject();
    if (column is! RenderBox || !column.hasSize) return;
    final tops = <Key, double>{};
    final heights = <Key, double>{};
    for (final entry in _boxes.entries) {
      final box = entry.value.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize || !box.attached) continue;
      tops[entry.key] = box.localToGlobal(Offset.zero, ancestor: column).dy;
      heights[entry.key] = box.size.height;
    }
    _tops = tops;
    _heights = heights;
  }

  @override
  void dispose() {
    _travel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keys = _keysOf(widget.children).toSet();
    _boxes.removeWhere((key, _) => !keys.contains(key));
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final child in widget.children)
          KeyedSubtree(
            key: child.key,
            // Measured outside the travel, so what is read is the place in
            // the layout, never a position in mid-flight.
            child: KeyedSubtree(
              key: _boxes.putIfAbsent(child.key!, GlobalKey.new),
              child: AnimatedBuilder(
                animation: _travel,
                // Always the same widget, at rest or moving: switching
                // between a bare row and a translated one would rebuild the
                // row from scratch, and a switch on it would snap instead
                // of sliding.
                builder: (context, row) {
                  final from = _from[child.key] ?? 0;
                  final left = _travel.isAnimating
                      ? 1 - MTMotion.ease.transform(_travel.value)
                      : 0.0;
                  return Transform.translate(
                    offset: Offset(0, from * left),
                    child: row,
                  );
                },
                child: child,
              ),
            ),
          ),
      ],
    );
  }
}
