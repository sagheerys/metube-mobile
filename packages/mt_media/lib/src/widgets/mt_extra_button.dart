import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

/// A button the app adds to a player for the item now playing: a feature
/// this package does not know, such as a transcript.
class MTExtraAction {
  const MTExtraAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;

  /// Read aloud and shown on a long press; the button itself is the icon
  /// alone.
  final String label;
  final VoidCallback onTap;
}

/// [MTExtraAction] as a filled round button in the action colour: the one
/// thing on the row that is not a setting, so it stands out from them.
class MTExtraButton extends StatelessWidget {
  const MTExtraButton({super.key, required this.extra, this.size = 40});

  final MTExtraAction extra;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Tooltip(
      message: extra.label,
      child: Material(
        color: p.accent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: extra.onTap,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: size,
            child: Icon(
              extra.icon,
              size: size * 0.55,
              color: p.onAccent,
              semanticLabel: extra.label,
            ),
          ),
        ),
      ),
    );
  }
}
