import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player/video_player.dart';

import '../models/playlist_item.dart';
import '../widgets/mt_queue_panel.dart';
import '../widgets/mt_up_next_list.dart';
import 'mt_video_controls.dart';
import 'mt_video_session.dart';

/// الوضع العرضي الغامر (مرجع «وهج» C/D): الفيديو ملء الشاشة، الأدوات
/// تظهر بلمسة وتختفي، وقائمة الانتظار **لوحة جانبية منزلقة** (م-38).
class MTVideoFullscreenPage extends StatefulWidget {
  const MTVideoFullscreenPage({
    super.key,
    required this.session,
    this.artwork,
    this.onSaveQueueAsPlaylist,
    this.onShowPlaylist,
    this.playlistName,
  });

  final MTVideoSession session;
  final MTArtworkBuilder? artwork;
  final VoidCallback? onSaveQueueAsPlaylist;
  final VoidCallback? onShowPlaylist;
  final String? playlistName;

  @override
  State<MTVideoFullscreenPage> createState() => _MTVideoFullscreenPageState();
}

class _MTVideoFullscreenPageState extends State<MTVideoFullscreenPage> {
  bool _queueOpen = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
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
                onBack: () => Navigator.of(context).maybePop(),
                onToggleFullscreen: () => Navigator.of(context).maybePop(),
                onQueue: () => setState(() => _queueOpen = true),
              ),
              if (_queueOpen)
                _SidePanel(
                  session: session,
                  artwork: widget.artwork,
                  playlistName: widget.playlistName,
                  onSaveAsPlaylist: widget.onSaveQueueAsPlaylist,
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

/// لوحة القائمة الجانبية: تنزلق من جهة البداية فوق الفيديو المعتم.
class _SidePanel extends StatelessWidget {
  const _SidePanel({
    required this.session,
    required this.onClose,
    this.artwork,
    this.onSaveAsPlaylist,
    this.onShowAll,
    this.playlistName,
  });

  final MTVideoSession session;
  final VoidCallback onClose;
  final MTArtworkBuilder? artwork;
  final VoidCallback? onSaveAsPlaylist;
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
              currentIndex:
                  ordered.indexWhere((i) => i.canonicalUrl == currentUrl),
              artwork: artwork,
              playlistName: playlistName,
              onSaveAsPlaylist: onSaveAsPlaylist,
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
    this.onSaveAsPlaylist,
    this.onShowAll,
    this.playlistName,
  });

  final List<PlaylistItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final MTArtworkBuilder? artwork;
  final VoidCallback? onSaveAsPlaylist;
  final VoidCallback? onShowAll;
  final String? playlistName;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Container(
      color: MTPalette.fullscreenScrim,
      padding: const EdgeInsets.fromLTRB(
          MTSpace.lg, MTSpace.lg, MTSpace.lg, MTSpace.md),
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
            onSaveAsPlaylist: onSaveAsPlaylist,
            onShowAll: onShowAll,
            onSelect: onSelect,
            dark: true,
          ),
        ),
      ),
    );
  }
}
