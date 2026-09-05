import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../models/playlist_item.dart';
import '../screens/mt_video_screen.dart';
import '../widgets/media_time.dart';

/// شريط الريلز العلوي: عودة · «⚡ قِصار ٣ / ١٤» · المزيد.
class MTReelsTopBar extends StatelessWidget {
  const MTReelsTopBar({
    super.key,
    required this.position,
    required this.total,
    required this.onBack,
    this.onMore,
  });

  final int position;
  final int total;
  final VoidCallback onBack;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final ink = MTPalette.serverCardInk;
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          tooltip: l10n.dismiss,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: ink),
        ),
        Expanded(
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MTSpace.md,
                vertical: MTSpace.xxs + 1,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(MTRadius.chip),
              ),
              child: Text(
                // العدّاد معزول: «2 / 40» كانت تُعرض «40 / 2».
                '⚡ ${l10n.shortsFilter}   ${mtLtrRun('$position / $total')}',
                style: Theme.of(context).textTheme.labelSmall!
                    .copyWith(color: ink, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        if (onMore != null)
          IconButton(
            onPressed: onMore,
            tooltip: l10n.details,
            icon: Icon(Icons.more_vert_rounded, color: ink),
          )
        else
          const SizedBox(width: 48),
      ],
    );
  }
}

/// عمود الأفعال الجانبي في متناول الإبهام (تفاصيل/أضف إلى/مشاركة).
///
/// **زر المفضلة اختياري** (بلاغ المالك 2026-09-04): التطبيقان يقدّمان
/// بدله زر «أضف إلى…» الذي يجمع المفضلة والوسم والقائمة في مكان واحد،
/// فبقاء قلبٍ مستقل كان تكراراً لفعل موجود. `onToggleFavorite = null`
/// ⇒ لا قلب — والضغطة المزدوجة على المقطع تبقى كما هي (م-36).
class MTReelsRail extends StatelessWidget {
  const MTReelsRail({
    super.key,
    this.favorite = false,
    this.onToggleFavorite,
    this.actions = const [],
  });

  final bool favorite;
  final VoidCallback? onToggleFavorite;
  final List<MTPlayerAction> actions;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l10n = context.mtl;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onToggleFavorite != null)
          _RailButton(
            icon: favorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            label: l10n.favorites,
            onTap: onToggleFavorite!,
            background: favorite ? p.favorite : null,
          ),
        for (final action in actions) ...[
          if (action != actions.first || onToggleFavorite != null)
            const SizedBox(height: MTSpace.lg),
          _RailButton(
            icon: action.icon,
            label: action.label,
            onTap: action.onTap,
            background: action.highlighted ? p.accent : null,
          ),
        ],
      ],
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.background,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final ink = MTPalette.serverCardInk;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: background ?? Colors.black.withValues(alpha: 0.42),
          borderRadius: BorderRadius.circular(MTRadius.card),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(MTRadius.card),
            child: SizedBox(
              width: 46,
              height: 46,
              child: Center(
                child: MTIconSwap(icon: icon, size: 20, color: ink),
              ),
            ),
          ),
        ),
        const SizedBox(height: MTSpace.xxs),
        SizedBox(
          width: 62,
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall!
                .copyWith(color: ink, fontSize: 9.5),
          ),
        ),
      ],
    );
  }
}

/// كتلة المعلومات أسفل الشاشة: رقاقة المصدر والمدة، العنوان، الناشر.
class MTReelsInfo extends StatelessWidget {
  const MTReelsInfo({super.key, required this.item, this.subtitle});

  final PlaylistItem item;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final ink = MTPalette.serverCardInk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (item.duration != null)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MTSpace.sm,
              vertical: MTSpace.xxs,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(MTRadius.badge + 2),
            ),
            child: Text(
              mtFormatDuration(item.duration!),
              style: text.labelSmall!
                  .copyWith(color: ink, fontWeight: FontWeight.w700)
                  .tabular,
            ),
          ),
        const SizedBox(height: MTSpace.xs),
        Text(
          item.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.titleMedium!.copyWith(color: ink, fontSize: 14.5),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: MTSpace.xxs),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall!.copyWith(color: ink.withValues(alpha: 0.7)),
          ),
        ],
      ],
    );
  }
}

/// بطاقة نهاية المسار: «انتهت القِصار» + عودة / متابعة بقية القائمة.
class MTReelsEndCard extends StatelessWidget {
  const MTReelsEndCard({
    super.key,
    required this.onBack,
    this.onContinueRest,
    this.onReplay,
  });

  final VoidCallback onBack;
  final VoidCallback? onContinueRest;
  final VoidCallback? onReplay;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l10n = context.mtl;
    return Center(
      child: Container(
        margin: const EdgeInsets.all(MTSpace.xxl),
        padding: const EdgeInsets.all(MTSpace.xl),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(MTRadius.sheet),
          border: Border.all(color: p.line),
          boxShadow: MTShadow.card,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bolt_rounded, size: 34, color: p.accent),
            const SizedBox(height: MTSpace.sm),
            Text(
              l10n.reelsEndTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: MTSpace.lg),
            if (onContinueRest != null)
              FilledButton(
                onPressed: onContinueRest,
                child: Text(l10n.reelsEndContinue),
              ),
            if (onReplay != null)
              TextButton(onPressed: onReplay, child: Text(l10n.reelsEndReplay)),
            TextButton(onPressed: onBack, child: Text(l10n.reelsEndBack)),
          ],
        ),
      ),
    );
  }
}
