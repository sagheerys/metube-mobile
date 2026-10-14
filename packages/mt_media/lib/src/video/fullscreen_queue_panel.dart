part of 'mt_video_fullscreen.dart';

/// The queue side panel: it slides in from the leading edge over the dimmed
/// video.
class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.session,
    required this.onClose,
    this.artwork,
    this.onShowAll,
    this.playlistName,
  });

  final MTVideoSession session;
  final VoidCallback onClose;
  final MTArtworkBuilder? artwork;
  final VoidCallback? onShowAll;
  final String? playlistName;

  @override
  Widget build(BuildContext context) {
    final ordered = session.orderedItems;
    final currentUrl = session.current?.canonicalUrl;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
          ),
        ),
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          width: 294,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -294, end: 0),
            duration: MTMotion.medium,
            curve: MTMotion.ease,
            builder: (context, offset, child) => Transform.translate(
              offset: Offset(
                Directionality.of(context) == TextDirection.rtl
                    ? -offset
                    : offset,
                0,
              ),
              child: child,
            ),
            child: _PanelBody(
              items: ordered,
              currentIndex: ordered.indexWhere(
                (i) => i.canonicalUrl == currentUrl,
              ),
              artwork: artwork,
              playlistName: playlistName,
              paused: !session.isPlaying,
              onShowAll: onShowAll,
              onSelect: (index) {
                onClose();
                session.jumpTo(session.items.indexOf(ordered[index]));
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _PanelBody extends StatelessWidget {
  const _PanelBody({
    required this.items,
    required this.currentIndex,
    required this.onSelect,
    this.artwork,
    this.onShowAll,
    this.playlistName,
    this.paused = false,
  });

  final List<PlaylistItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final MTArtworkBuilder? artwork;
  final VoidCallback? onShowAll;
  final String? playlistName;
  final bool paused;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Container(
      color: MTPalette.fullscreenScrim,
      padding: const EdgeInsets.fromLTRB(
        MTSpace.lg,
        MTSpace.lg,
        MTSpace.lg,
        MTSpace.md,
      ),
      child: SafeArea(
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: BorderDirectional(
              end: BorderSide(color: p.miniInk.withValues(alpha: 0.12)),
            ),
          ),
          child: MTQueuePanel(
            items: items,
            currentIndex: currentIndex,
            artwork: artwork,
            playlistName: playlistName,
            paused: paused,
            onShowAll: onShowAll,
            onSelect: onSelect,
            dark: true,
          ),
        ),
      ),
    );
  }
}
