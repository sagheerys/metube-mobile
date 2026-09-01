import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// زر مساعدة (؟) لحقل معقد (م-34) — يفتح حواراً بشرح من arb.
class HelpButton extends StatelessWidget {
  const HelpButton({super.key, required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: context.mtl.helpAboutField,
      icon: Icon(Icons.help_outline_rounded, size: 18, color: p.ink3),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title,
              style: Theme.of(dialogContext).textTheme.titleLarge),
          content: Text(body,
              style: Theme.of(dialogContext).textTheme.bodyMedium),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(MaterialLocalizations.of(dialogContext)
                  .okButtonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
