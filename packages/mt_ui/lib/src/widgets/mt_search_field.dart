import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';

/// The always-visible search field: search is on screen, not behind an
/// icon.
class MTSearchField extends StatelessWidget {
  const MTSearchField({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.autofocus = false,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final x = MTThemeX.of(context);
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(Icons.search_rounded, size: 20, color: x.palette.ink3),
        isDense: true,
      ),
    );
  }
}

/// A search field that shows [query] whatever happened to it: the text is
/// the query held elsewhere, not the field's own.
///
/// **Field report 2026-09-30:** the library's search field sits in a lazy
/// list, so scrolling far down disposed it. Its text went with it, while
/// the query it had set stayed on and kept filtering the library, with
/// an empty field above the results. Rebuilt, this field takes its text
/// from [query] again.
class MTQuerySearchField extends StatefulWidget {
  const MTQuerySearchField({
    super.key,
    required this.hint,
    required this.query,
    required this.onChanged,
  });

  final String hint;
  final String query;
  final ValueChanged<String> onChanged;

  @override
  State<MTQuerySearchField> createState() => _MTQuerySearchFieldState();
}

class _MTQuerySearchFieldState extends State<MTQuerySearchField> {
  late final _controller = TextEditingController(text: widget.query);

  @override
  void didUpdateWidget(MTQuerySearchField old) {
    super.didUpdateWidget(old);
    // Cleared or changed from outside: follow it, keeping the caret at the
    // end rather than jumping to the start.
    if (widget.query != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MTSearchField(
    hint: widget.hint,
    controller: _controller,
    onChanged: widget.onChanged,
  );
}
