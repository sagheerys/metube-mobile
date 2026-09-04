import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../l10n/l10n.dart';
import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import 'mt_equalizer.dart';
import 'mt_highlight_surface.dart';
import 'mt_platform_chip.dart';

/// موقع العنصر — يلوّن شارته: «دون اتصال» زيتوني · «على السيرفر» وهج soft.
enum MTMediaLocation { none, offline, onServer, both }

/// بطاقة الوسائط «وهج»: صف مفصول بخيط شعري (لا صندوق) — كاملة أو مضغوطة.
/// عرض بحت: كل البيانات نصوص وأعلام جاهزة من طبقة التطبيق.
class MTMediaCard extends StatelessWidget {
  const MTMediaCard({
    super.key,
    required this.title,
    this.thumbnail,
    this.duration,
    this.platform = MTPlatformKind.other,
    this.subtitle,
    this.location = MTMediaLocation.none,
    this.locationLabel,
    this.compact = false,
    this.selected = false,
    this.highlighted = false,
    this.playing = false,
    this.paused = false,
    this.favorite = false,
    this.onTap,
    this.onLongPress,
    this.onFavoriteToggle,
    this.onMore,
  });

  final String title;

  /// المصغرة يقدمها التطبيق (cached_network_image / ملف محلي).
  final Widget? thumbnail;
  final String? duration;
  final MTPlatformKind platform;
  final String? subtitle;
  final MTMediaLocation location;
  final String? locationLabel;
  final bool compact;
  final bool selected;

  /// **توهّج واحد يتلاشى** — «انظر هنا»، لا «هذا محدد».
  ///
  /// كان المنادي يمرّر `selected: true` ليبرز عنصراً وصله المستخدم من
  /// نقرة إشعار أو اكتمل تحميله للتو. لكن `selected` تعني في كل مكان
  /// آخر «داخل التحديد الجماعي»، فبدا العنصر عالقاً في وضع تحديد لا
  /// يخرج منه — وهو بالضبط ما وصفه المالك بـ«يظل مؤشراً على طول».
  /// الآن حالتان مختلفتان بصرياً ودلالياً: التحديد يثبت، والتوهج يمضي.
  final bool highlighted;
  final bool playing;

  /// [playing] يعني «هذا هو العنصر الحالي»؛ [paused] يعني أنه متوقف
  /// مؤقتاً — فيظهر المؤشر ساكناً بدل أن يرقص على مقطع لا يعمل.
  final bool paused;
  final bool favorite;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onMore;

  /// وصف قارئ الشاشة: العنوان ثم ما يميّز حالة البطاقة (م-2.7 «RTL
  /// وSemantics»). يُبنى نصاً واحداً لأن القارئ يقرأ البطاقة كوحدة.
  String _semanticsLabel(MTLocalizations l10n) => [
        title,
        ?subtitle,
        ?locationLabel,
        if (favorite) l10n.favorites,
        if (playing) l10n.nowPlaying,
      ].join('، ');

  @override
  Widget build(BuildContext context) {
    final x = MTThemeX.of(context);
    final p = x.palette;
    final l10n = context.mtl;
    final text = Theme.of(context).textTheme;
    final thumbW = compact ? 64.0 : 98.0;
    final thumbH = compact ? 40.0 : 62.0;

    return Semantics(
      button: onTap != null,
      selected: selected,
      label: _semanticsLabel(l10n),
      // الأزرار الداخلية تحتفظ بدلالتها؛ النصوص تُستبدل بالوصف الموحّد.
      explicitChildNodes: true,
      child: MTHighlightSurface(
        selected: selected,
        highlighted: highlighted,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress == null
              ? null
              : () {
                  // ر-6: الدخول لوضع التحديد يستحق نبضة تأكيد.
                  HapticFeedback.selectionClick();
                  onLongPress!();
                },
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: compact ? MTSpace.xs : MTSpace.md - 1,
              horizontal: 2,
            ),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: p.line)),
            ),
          child: Row(
            children: [
              _Thumb(
                  width: thumbW,
                  height: thumbH,
                  duration: duration,
                  playing: playing,
                  child: thumbnail),
              const SizedBox(width: MTSpace.md - 1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: compact ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodyMedium!
                          .copyWith(fontWeight: FontWeight.w700, height: 1.55),
                    ),
                    SizedBox(height: compact ? 3 : 6),
                    Row(
                      children: [
                        // المنصة المجهولة لا تستحق رمزاً ولا فاصلاً:
                        // «• · منذ ٣ دقائق» ضجيج بصري (تدقيق 8.1).
                        if (platform != MTPlatformKind.other)
                          MTPlatformChip(kind: platform),
                        if (subtitle != null) ...[
                          if (platform != MTPlatformKind.other)
                            Text(' · ',
                                style:
                                    text.bodySmall!.copyWith(color: p.ink3)),
                          Flexible(
                            child: Text(subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall!
                                    .copyWith(color: p.ink3)),
                          ),
                        ],
                        if (location != MTMediaLocation.none &&
                            locationLabel != null) ...[
                          const SizedBox(width: MTSpace.xs),
                          _LocationBadge(
                              location: location, label: locationLabel!),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (playing)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: MTSpace.xs),
                  child: MTEqualizer(animate: !paused),
                ),
              if (onFavoriteToggle != null)
                IconButton(
                  tooltip: favorite
                      ? l10n.removeFromFavorites
                      : l10n.addToFavorites,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onFavoriteToggle!();
                  },
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    favorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 20,
                    color: favorite ? p.favorite : p.ink3,
                  ),
                ),
              if (onMore != null)
                IconButton(
                  tooltip: l10n.itemOptions,
                  onPressed: onMore,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(Icons.more_vert_rounded,
                      size: 20, color: p.ink3),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({
    required this.width,
    required this.height,
    this.duration,
    this.playing = false,
    this.child,
  });

  final double width;
  final double height;
  final String? duration;
  final bool playing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: p.cardAlt,
        borderRadius: BorderRadius.circular(MTRadius.thumb),
        border: Border.all(color: p.line),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          child ??
              Icon(Icons.music_note_rounded, size: 20, color: p.ink3),
          if (duration != null)
            PositionedDirectional(
              bottom: 5,
              start: 5,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
        ],
      ),
    );
  }
}

class _LocationBadge extends StatelessWidget {
  const _LocationBadge({required this.location, required this.label});

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
