import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../l10n/l10n.dart';
import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import 'mt_equalizer.dart';
import 'mt_highlight_surface.dart';
import 'mt_media_card.dart' show MTMediaLocation;
import 'mt_platform_chip.dart';

/// بطاقة المكتبة في **العرض الشبكي**: المصغرة تتصدر بنسبة 16:9 والعنوان
/// تحتها سطران. الصف الواحد يعرض ضعف ما تعرضه القائمة، فالمسح البصري
/// للفيديو أسرع بكثير — والقائمة تبقى الأنسب للصوتيات وللعناوين الطويلة.
///
/// عرض بحت مثل [MTMediaCard] تماماً: لا تعرف سيرفراً ولا فهرساً.
class MTMediaGridCard extends StatelessWidget {
  const MTMediaGridCard({
    super.key,
    required this.title,
    this.thumbnail,
    this.duration,
    this.platform = MTPlatformKind.other,
    this.subtitle,
    this.location = MTMediaLocation.none,
    this.locationLabel,
    this.selected = false,
    this.highlighted = false,
    this.playing = false,
    this.favorite = false,
    this.onTap,
    this.onLongPress,
    this.onFavoriteToggle,
    this.onMore,
  });

  final String title;
  final Widget? thumbnail;
  final String? duration;
  final MTPlatformKind platform;
  final String? subtitle;
  final MTMediaLocation location;
  final String? locationLabel;
  final bool selected;
  final bool highlighted;
  final bool playing;
  final bool favorite;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onMore;

  String _semanticsLabel(MTLocalizations l10n) => [
        title,
        ?subtitle,
        ?locationLabel,
        if (favorite) l10n.favorites,
        if (playing) l10n.nowPlaying,
      ].join('، ');

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l10n = context.mtl;
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: _semanticsLabel(l10n),
      explicitChildNodes: true,
      child: MTHighlightSurface(
        selected: selected,
        highlighted: highlighted,
        borderRadius: BorderRadius.circular(MTRadius.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MTRadius.card),
          onLongPress: onLongPress == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  onLongPress!();
                },
          child: Padding(
            padding: const EdgeInsets.all(MTSpace.xxs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _Cover(
                  duration: duration,
                  playing: playing,
                  favorite: favorite,
                  onFavoriteToggle: onFavoriteToggle,
                  onMore: onMore,
                  child: thumbnail,
                ),
                const SizedBox(height: MTSpace.xs),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall!.copyWith(
                    color: p.ink,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (platform != MTPlatformKind.other) ...[
                      MTPlatformChip(kind: platform),
                      const SizedBox(width: MTSpace.xxs),
                    ],
                    if (subtitle != null)
                      Flexible(
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall!.copyWith(color: p.ink3),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// المصغرة 16:9 وفوقها المدة والمفضلة والمزيد — أفعال البطاقة كلها
/// تعيش على الغلاف لأن الشبكة لا تملك عرضاً لصف أزرار جانبي.
class _Cover extends StatelessWidget {
  const _Cover({
    required this.duration,
    required this.playing,
    required this.favorite,
    required this.onFavoriteToggle,
    required this.onMore,
    this.child,
  });

  final String? duration;
  final bool playing;
  final bool favorite;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onMore;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l10n = context.mtl;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: p.cardAlt,
          borderRadius: BorderRadius.circular(MTRadius.thumb),
          border: Border.all(color: p.line),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            child ?? Icon(Icons.music_note_rounded, size: 22, color: p.ink3),
            if (playing)
              Align(
                alignment: Alignment.center,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: p.ink.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(MTSpace.xs),
                    child: MTEqualizer(),
                  ),
                ),
              ),
            if (duration != null)
              PositionedDirectional(
                bottom: 5,
                start: 5,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: p.ink.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    duration!,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: p.bg,
                    ).tabular,
                  ),
                ),
              ),
            PositionedDirectional(
              top: 0,
              end: 0,
              child: Row(
                children: [
                  if (onFavoriteToggle != null)
                    _CoverButton(
                      icon: favorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      tooltip: favorite
                          ? l10n.removeFromFavorites
                          : l10n.addToFavorites,
                      // **أبيض ثابت لا `p.bg` (العطل م-3):** الرقاقة فوق
                      // غلاف داكن دائماً، فكان لون خلفية الثيم يجعلها
                      // ليلاً داكنة على داكن — شبه مخفية.
                      color: favorite ? p.favorite : Colors.white,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onFavoriteToggle!();
                      },
                    ),
                  if (onMore != null)
                    _CoverButton(
                      icon: Icons.more_vert_rounded,
                      tooltip: l10n.itemOptions,
                      color: Colors.white,
                      onTap: onMore!,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverButton extends StatelessWidget {
  const _CoverButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(MTSpace.xs),
            child: Icon(
              icon,
              size: 17,
              color: color,
              // الأيقونات فوق مصغرة مجهولة اللون: ظل خفيف يضمن قراءتها
              // على غلاف فاتح وداكن معاً.
              shadows: const [
                Shadow(color: Color(0x99000000), blurRadius: 5),
              ],
            ),
          ),
        ),
      );
}
