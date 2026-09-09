import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import 'mt_media_card.dart' show MTMediaLocation;

/// The location badge on a library card: olive for "offline", soft ember
/// for "on the server" (log §4, the language of meaning). Split out of
/// `mt_media_card.dart` when that file reached the size limit (rule 4).
class MTLocationBadge extends StatelessWidget {
  const MTLocationBadge({
    super.key,
    required this.location,
    required this.label,
  });

  final MTMediaLocation location;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final (bg, fg) = location == MTMediaLocation.offline
        ? (p.offlineSoft, p.offlineInk)
        : (p.onServerSoft, p.onServerInk);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MTRadius.badge),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: MTType.body,
          package: MTType.package,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}
