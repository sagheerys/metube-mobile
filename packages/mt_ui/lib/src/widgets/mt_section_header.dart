import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// رأس قسم «وهج»: عنوان كوفي + نص ثانوي، وفاصل شعري سفلي —
/// الفواصل بدل الصناديق (سجل §4).
class MTSectionHeader extends StatelessWidget {
  const MTSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final x = MTThemeX.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          MTSpace.xxs, MTSpace.xxs, MTSpace.xxs, MTSpace.sm),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: x.palette.line)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(child: Text(title, style: text.titleMedium)),
          if (trailing != null)
            Text(trailing!,
                style: text.bodySmall!.copyWith(color: x.palette.ink3)),
        ],
      ),
    );
  }
}
