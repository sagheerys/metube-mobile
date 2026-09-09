import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';

/// A Wahaj empty state: an icon on a soft disc, a Kufi heading, an
/// explanation and an optional action.
class MTEmptyState extends StatelessWidget {
  const MTEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final x = MTThemeX.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MTSpace.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: x.palette.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 30, color: x.palette.accentInk),
            ),
            const SizedBox(height: MTSpace.lg),
            Text(title, style: text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: MTSpace.xs),
            Text(
              message,
              style: text.bodyMedium!.copyWith(color: x.palette.ink2),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: MTSpace.xl),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
