import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';

/// Platform kinds **as far as presentation is concerned**. mt_ui does not
/// know mt_core (dependency rule 6), so the app converts `MediaPlatform`
/// into this type.
enum MTPlatformKind {
  youtube('YT', Color(0xFFA8442F)),
  tiktok('TT', Color(0xFF3E6273)),
  instagram('IG', Color(0xFFA34E68)),
  soundcloud('SC', Color(0xFF9A6B10)),
  x('X', Color(0xFF4A4440)),
  facebook('FB', Color(0xFF3E5273)),
  vimeo('VM', Color(0xFF3E6E73)),
  twitch('TW', Color(0xFF6B4E9A)),
  reddit('RD', Color(0xFFA85A2F)),
  dailymotion('DM', Color(0xFF445A8A)),
  other('•', Color(0x00000000));

  const MTPlatformKind(this.label, this.tint);

  final String label;

  /// A warm text shade from the Wahaj family; [other] falls back to ink3
  /// from the palette.
  final Color tint;
}

/// The compact textual platform badge inside a card's meta row.
class MTPlatformChip extends StatelessWidget {
  const MTPlatformChip({super.key, required this.kind});

  final MTPlatformKind kind;

  @override
  Widget build(BuildContext context) {
    final x = MTThemeX.of(context);
    return Text(
      kind.label,
      style: Theme.of(context).textTheme.labelSmall!.copyWith(
            color: kind == MTPlatformKind.other ? x.palette.ink3 : kind.tint,
            fontWeight: FontWeight.w700,
          ),
    );
  }
}
