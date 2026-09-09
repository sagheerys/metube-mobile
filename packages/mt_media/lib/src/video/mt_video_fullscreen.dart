import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player/video_player.dart';

import '../models/playlist_item.dart';
import '../widgets/mt_queue_panel.dart';
import '../widgets/mt_up_next_list.dart';
import 'mt_orientation.dart';
import 'mt_video_controls.dart';
import 'mt_video_session.dart';

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
  });

  final MTVideoSession session;
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

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    if (widget.byRotation) {
      MTOrientation.allow();
    } else {
      MTOrientation.lockLandscape();
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // **We do not lock portrait here**: the portrait player beneath us is
    // still alive and owns the policy. Locking from here pinned the whole
    // app to portrait forever.
    MTOrientation.allow();
    super.dispose();
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
              ),
              if (_queueOpen)
                _SidePanel(
                  session: session,
                  artwork: widget.artwork,
                  playlistName: widget.playlistName,
                  onShowAll: widget.onShowPlaylist,
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
