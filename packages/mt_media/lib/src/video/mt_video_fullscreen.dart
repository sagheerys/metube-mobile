import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player/video_player.dart';

import '../models/playlist_item.dart';
import '../widgets/mt_extra_button.dart';
import '../widgets/mt_queue_panel.dart';
import '../widgets/mt_up_next_list.dart';
import 'mt_orientation.dart';
import 'mt_video_controls.dart';
import 'mt_video_session.dart';
import 'video_side_panel.dart';

/// Immersive landscape (Wahaj references C and D): the video fills the
/// screen, the chrome appears on a touch and hides again, and the queue is
/// **a sliding side panel**.
class MTVideoFullscreenPage extends StatefulWidget {
  const MTVideoFullscreenPage({
    super.key,
    required this.session,
    this.artwork,
    this.onShowPlaylist,
    this.playlistName,
    this.membershipLine,
    this.byRotation = false,
    this.panel,
  });

  final MTVideoSession session;

  /// Asked again for each item as the queue moves; null, or a null answer,
  /// shows no button.
  final MTVideoPanel? Function(PlaylistItem item)? panel;
  final MTArtworkBuilder? artwork;
  final VoidCallback? onShowPlaylist;
  final String? playlistName;

  /// Where the clip belongs (tags and playlists), shown under the title in
  /// landscape.
  final String? membershipLine;

  /// **We entered by tilting the device rather than by the button.** The
  /// difference is behavioural: entering by tilt leaves on the opposite
  /// tilt (as YouTube does), while entering by the button stays landscape
  /// until exit is pressed, because someone with rotation locked cannot
  /// tilt at all.
  final bool byRotation;

  @override
  State<MTVideoFullscreenPage> createState() => _MTVideoFullscreenPageState();
}

class _MTVideoFullscreenPageState extends State<MTVideoFullscreenPage> {
  bool _queueOpen = false;

  /// The item the panel was opened for. **It belongs to that item**: when
  /// the queue moves on the panel closes, rather than show the previous
  /// clip's transcript against the new clip's time, and it does not open
  /// again by itself on a later item.
  String? _panelFor;

  /// The shape the button locked the screen for: portrait for a portrait
  /// clip, landscape otherwise. Null until decided.
  bool? _lockedPortrait;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (widget.byRotation) {
      MTOrientation.allow();
    } else {
      _lockForShape();
      widget.session.addListener(_lockForShape);
    }
  }

  /// **A portrait clip fills the screen standing up** (field report
  /// 2026-10-04). Turned sideways, a portrait clip too long for the shorts
  /// player sits small in the middle, and in a hand that holds it upright,
  /// the way a portrait clip is held, it lies on its side.
  /// Decided again as the queue moves, since the next clip may be the
  /// other shape. Entering by a tilt keeps the tilt: that user chose
  /// landscape.
  void _lockForShape() {
    final portrait = _isPortrait();
    if (portrait == _lockedPortrait) return;
    _lockedPortrait = portrait;
    portrait ? MTOrientation.lockPortrait() : MTOrientation.lockLandscape();
  }

  bool _isPortrait() {
    final controller = widget.session.controller;
    if (controller != null && controller.value.isInitialized) {
      return controller.value.aspectRatio < 1;
    }
    final ratio = widget.session.current?.aspectRatio;
    return ratio != null && ratio < 1;
  }

  @override
  void dispose() {
    widget.session.removeListener(_lockForShape);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // **We do not lock portrait here**: the portrait player beneath us is
    // still alive and owns the policy. Locking from here pinned the whole
    // app to portrait forever.
    MTOrientation.allow();
    super.dispose();
  }

  /// **Leave fullscreen first, then open the playlist** (field report
  /// 2026-09-19: "the picture disappears and it keeps playing with the
  /// phone stuck sideways").
  ///
  /// The callback pushes the playlists screen, and pushing it **over** this
  /// page left this page alive underneath: its [dispose] never ran, so the
  /// immersive mode and the landscape lock it installed stayed in force
  /// over a screen that wanted neither, while the video played on behind
  /// it. Popping first lets [dispose] restore the system bars and the
  /// orientation before anything else is shown.
  void _leaveThenShowPlaylist(BuildContext context) {
    final show = widget.onShowPlaylist;
    if (show == null) return;
    // **Restored here, not left to [dispose]:** the pop starts a
    // transition, and this page — and its dispose — lives until the
    // transition ends, well after the frame below. The playlist would open
    // under the immersive mode and the landscape lock for the length of
    // the animation. Dispose repeating both is harmless.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    MTOrientation.allow();
    Navigator.of(context).pop();
    // After the frame that removes this route from the top.
    WidgetsBinding.instance.addPostFrameCallback((_) => show());
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    // Leaving on the opposite tilt, for whoever entered that way.
    if (widget.byRotation &&
        MediaQuery.orientationOf(context) == Orientation.portrait) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
          Navigator.of(context).maybePop();
        }
      });
    }
    return Scaffold(
      backgroundColor: Colors.black,
      body: ListenableBuilder(
        listenable: session,
        builder: (context, _) {
          final controller = session.controller;
          final panel = switch (session.current) {
            final item? => widget.panel?.call(item),
            null => null,
          };
          // Another clip is playing: the open panel was for the last one.
          // Forgotten here, so going back to it does not reopen it either.
          if (_panelFor != session.current?.canonicalUrl) _panelFor = null;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (controller != null && controller.value.isInitialized)
                Center(
                  child: AspectRatio(
                    aspectRatio: controller.value.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                )
              else
                const Center(child: CircularProgressIndicator()),
              MTVideoControls(
                session: session,
                fullscreen: true,
                playlistName: widget.playlistName,
                membershipLine: widget.membershipLine,
                onBack: () => Navigator.of(context).maybePop(),
                onToggleFullscreen: () => Navigator.of(context).maybePop(),
                onQueue: () => setState(() => _queueOpen = true),
                extra: panel == null
                    ? null
                    : MTExtraAction(
                        icon: panel.icon,
                        label: panel.label,
                        onTap: () => setState(
                          () => _panelFor = session.current?.canonicalUrl,
                        ),
                      ),
              ),
              if (panel != null &&
                  _panelFor != null &&
                  _panelFor == session.current?.canonicalUrl)
                MTVideoEndPanel(
                  key: ValueKey(_panelFor),
                  child: panel.builder(
                    context,
                    () => setState(() => _panelFor = null),
                  ),
                ),
              if (_queueOpen)
                _SidePanel(
                  session: session,
                  artwork: widget.artwork,
                  playlistName: widget.playlistName,
                  onShowAll: widget.onShowPlaylist == null
                      ? null
                      : () => _leaveThenShowPlaylist(context),
                  onClose: () => setState(() => _queueOpen = false),
                ),
            ],
          );
        },
      ),
    );
  }
}

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
