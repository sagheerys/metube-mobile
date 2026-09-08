import 'package:flutter/material.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../playlists_providers.dart';

/// بطاقة قائمة ذكية (م-37/أ): إسبريسو داكنة مصغرة بتوهّج علوي — تُبنى
/// وحدها بلا صيانة، ولونها يتبع معناها (مفضلة قرمزي · دون اتصال زيتوني).
class SmartPlaylistCard extends StatelessWidget {
  const SmartPlaylistCard({
    super.key,
    required this.kind,
    required this.count,
    required this.onTap,
  });

  final SmartListKind kind;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final l10n = context.mtl;
    final (icon, label, glow) = switch (kind) {
      SmartListKind.favorites => (
        Icons.favorite_rounded,
        l10n.favorites,
        p.favorite,
      ),
      SmartListKind.latest => (
        Icons.schedule_rounded,
        l10n.latestAdditions,
        p.accent,
      ),
      SmartListKind.offline => (
        Icons.download_done_rounded,
        l10n.offlineSmartList,
        p.offline,
      ),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MTRadius.card),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MTRadius.card),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MTPalette.serverCardBg, MTPalette.serverCardBgLift],
            ),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // توهّج ناعم أعلى البطاقة — تدرّج شعاعي يتلاشى، لا قرص حاد.
              PositionedDirectional(
                top: -34,
                end: -24,
                child: Container(
                  width: 110,
                  height: 92,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        glow.withValues(alpha: 0.32),
                        glow.withValues(alpha: 0),
                      ],
                      stops: const [0.25, 1],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MTSpace.sm + 1,
                  vertical: MTSpace.md - 1,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: MTPalette.serverCardInk.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(MTRadius.chip),
                      ),
                      child: Icon(icon, size: 15, color: glow),
                    ),
                    const SizedBox(height: MTSpace.xs + 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: MTPalette.serverCardInk,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${l10n.queueItemsCount(count)} · ${l10n.autoBuilt}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        color: MTPalette.serverCardInk.withValues(alpha: 0.65),
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// بطاقة قائمة يدوية (م-37/ب): غلاف فسيفسائي حتى أربع مصغرات
/// + زر تشغيل + شارة تثبيت.
class PlaylistCard extends StatelessWidget {
  const PlaylistCard({
    super.key,
    required this.playlist,
    required this.onTap,
    required this.onPlay,
    required this.onLongPress,
    this.thumbnails = const [],
  });

  final SavedPlaylist playlist;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onLongPress;

  /// حتى أربعة أغلفة من عناصر القائمة (قد تكون فارغة).
  final List<Widget> thumbnails;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final l10n = context.mtl;

    return Material(
      color: p.card,
      borderRadius: BorderRadius.circular(MTRadius.cardLg),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(MTRadius.cardLg),
        child: Container(
          padding: const EdgeInsets.all(MTSpace.xs + 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MTRadius.cardLg),
            border: Border.all(
              color: playlist.pinned ? p.accent.withValues(alpha: 0.4) : p.line,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الغلاف يملأ ما تبقى من البطاقة فلا تبقى فراغات ميتة.
              Expanded(
                child: _Cover(
                  thumbnails: thumbnails,
                  pinned: playlist.pinned,
                  pinnedLabel: l10n.pinPlaylist,
                  onPlay: onPlay,
                ),
              ),
              const SizedBox(height: MTSpace.xs + 1),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Text(
                  playlist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.titleMedium!.copyWith(fontSize: 12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(3, 3, 3, 3),
                child: Text(
                  [
                    l10n.queueItemsCount(playlist.items.length),
                    if (playlist.lastPlayedAt != null)
                      mtTimeAgo(context, playlist.lastPlayedAt!),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall!.copyWith(color: p.ink3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Cover extends StatelessWidget {
  const _Cover({
    required this.thumbnails,
    required this.pinned,
    required this.pinnedLabel,
    required this.onPlay,
  });

  final List<Widget> thumbnails;
  final bool pinned;
  final String pinnedLabel;
  final VoidCallback onPlay;


  /// **فسيفساء تتكيّف مع العدد** (طلب المالك 2026-09-08): كانت خليّتين
  /// دائماً، فقائمة من عشرين عنصراً تُعرَّف بغلافين اثنين. الآن حتى
  /// أربعة — والتدرّج مقصود: **الثلاثة كبيرةٌ واثنتان** لا شبكةٌ فيها
  /// ربعٌ فارغ، والواحدة تملأ الغلاف بدل نصفٍ ميت.
  ///
  /// **و`stretch` إلزامي في كل صف وعمود** (فحص جهاز المالك 2026-09-05):
  /// بدونه لا تتلقى الخليّة ارتفاعاً مشدوداً فتأخذ الصورة ارتفاعها
  /// الطبيعي وتتوسّط — شريطٌ رفيع وسط بطاقة فارغة، و`BoxFit.cover`
  /// لا ينفع لأن لا شيء يطلب منه ملء الارتفاع.
  Widget _mosaic(BuildContext context, MTPalette p) {
    Widget cell(Widget? child) => ColoredBox(
          color: p.cardAlt,
          child: child ??
              Icon(Icons.queue_music_rounded, size: 18, color: p.ink3),
        );
    Widget stretchRow(List<Widget> children) => Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final child in children) Expanded(child: child)],
        );
    Widget stretchColumn(List<Widget> children) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [for (final child in children) Expanded(child: child)],
        );

    final t = thumbnails;
    return switch (t.length) {
      0 => cell(null),
      1 => cell(t[0]),
      2 => stretchRow([cell(t[0]), cell(t[1])]),
      3 => stretchRow([
          cell(t[0]),
          stretchColumn([cell(t[1]), cell(t[2])]),
        ]),
      _ => stretchColumn([
          stretchRow([cell(t[0]), cell(t[1])]),
          stretchRow([cell(t[2]), cell(t[3])]),
        ]),
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(MTRadius.thumb),
          child: _mosaic(context, p),
        ),
        if (pinned)
          PositionedDirectional(
            top: 6,
            start: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MTSpace.xs,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: p.ink.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(MTRadius.badge + 1),
              ),
              child: Text(
                '📌 $pinnedLabel',
                style: Theme.of(context).textTheme.labelSmall!
                    .copyWith(color: p.bg, fontSize: 9),
              ),
            ),
          ),
        PositionedDirectional(
          bottom: 6,
          end: 6,
          child: Material(
            color: p.ink.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(MTRadius.chip),
            child: InkWell(
              onTap: onPlay,
              borderRadius: BorderRadius.circular(MTRadius.chip),
              child: SizedBox(
                width: 28,
                height: 28,
                child: Icon(Icons.play_arrow_rounded, size: 16, color: p.bg),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
