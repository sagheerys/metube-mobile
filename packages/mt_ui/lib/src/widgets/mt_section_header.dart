import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// A Wahaj section header: a Kufi title, a secondary line and a hairline
/// rule beneath. Rules instead of boxes (log §4).
class MTSectionHeader extends StatelessWidget {
  const MTSectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.action,
  });

  final String title;
  final String? trailing;

  /// A small button at the end of the line, such as help for the section.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final x = MTThemeX.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        MTSpace.xxs,
        MTSpace.xxs,
        MTSpace.xxs,
        MTSpace.sm,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: x.palette.line)),
      ),
      child: Row(
        // A button has no baseline to sit on, so a header with one centres
        // its line instead; a header without one is laid out as before.
        crossAxisAlignment: action == null
            ? CrossAxisAlignment.baseline
            : CrossAxisAlignment.center,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(title, style: text.titleMedium)),
          if (trailing != null)
            Text(
              trailing!,
              style: text.bodySmall!.copyWith(color: x.palette.ink3),
            ),
          ?action,
        ],
      ),
    );
  }
}
