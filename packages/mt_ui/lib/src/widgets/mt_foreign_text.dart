import 'package:flutter/material.dart';

import '../l10n/bidi.dart';

/// Text the app did not write, a title above all, in its own direction:
/// an English title under the Arabic interface otherwise shows its closing
/// "!" at the front and its ellipsis at the wrong end. See [mtForeignLine].
class MTForeignText extends StatelessWidget {
  const MTForeignText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow = TextOverflow.ellipsis,
    this.center = false,
    this.selectable = false,
  });

  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;

  /// Centred rather than aligned with the interface.
  final bool center;

  /// Can be selected and copied: a long press on a phone, a drag on
  /// Windows. Selected whole, it copies the whole title, the part cut off
  /// by [maxLines] too.
  final bool selectable;

  @override
  Widget build(BuildContext context) {
    final (direction, align) = mtForeignLine(context, text);
    final line = Text(
      text,
      textDirection: direction,
      textAlign: center ? TextAlign.center : align,
      maxLines: maxLines,
      overflow: overflow,
      style: style,
    );
    return selectable ? MTSelectable(child: line) : line;
  }
}

/// The text selectable, and let go by a tap anywhere else. On its own a
/// selection stayed, its copy menu over the video, until the title was
/// touched again (seen on the emulator 2026-11-11): the region clears its
/// selection only when it loses focus, and a tap on the picture took none.
class MTSelectable extends StatefulWidget {
  const MTSelectable({super.key, required this.child});

  final Widget child;

  @override
  State<MTSelectable> createState() => _MTSelectableState();
}

class _MTSelectableState extends State<MTSelectable> {
  final _focus = FocusNode(debugLabel: 'selectable text');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TapRegion(
    // In the group Flutter puts the selection's handles and its copy menu
    // in: outside it, a touch on "Select all" or on a handle counted as a
    // tap elsewhere and let the selection go before it could act (owner's
    // report 2026-11-11).
    groupId: SelectableRegion,
    onTapOutside: (_) {
      if (_focus.hasFocus) _focus.unfocus();
    },
    child: SelectionArea(focusNode: _focus, child: widget.child),
  );
}
