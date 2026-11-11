import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mt_ui/mt_ui.dart';

import '../models/playlist_item.dart';
import '../widgets/mt_chapters.dart';
import '../widgets/mt_extra_button.dart';
import '../widgets/mt_queue_panel.dart';
import '../widgets/mt_up_next_list.dart';
import 'mt_orientation.dart';
import 'mt_picture_in_picture.dart';
import 'mt_video_controls.dart';
import 'mt_video_frame.dart';
import 'mt_video_session.dart';
import 'video_side_panel.dart';
import 'mt_captions.dart';

part 'fullscreen_queue_panel.dart';

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
    this.captions,
    this.chapters,
  });

  final MTVideoSession session;

  /// Asked again for each item as the queue moves; null, or a null answer,
  /// shows no button.
  final MTVideoPanel? Function(PlaylistItem item)? panel;

  /// The subtitles of the item playing; see [MTVideoScreen.captions].
  final MTCaptions? Function(PlaylistItem item)? captions;
  final MTArtworkBuilder? artwork;

  /// The chapters of the item playing; see [MTVideoScreen.chapters].
  final List<MTChapter> Function(PlaylistItem item)? chapters;
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
    // A tablet is not turned to fit a clip: it stands where it was put.
    if (MTOrientation.largeScreen) return;
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
    // **Not a plain portrait lock**: the portrait player beneath us is still
    // alive and owns the policy, and a lock from here pinned the whole app
    // to portrait forever. Upright until the phone is, then free.
    _release();
    super.dispose();
  }

  bool _released = false;
  bool _watchingPop = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_watchingPop) return;
    // Completes as the page is popped, by the button, back or a tilt.
    final popped = ModalRoute.of(context)?.popped;
    if (popped == null) return;
    _watchingPop = true;
    unawaited(popped.then((_) => _release()));
  }

  /// Once, as the page starts to leave: at the pop, not after its
  /// transition, so the page beneath never lies on its side meanwhile.
  void _release() {
    if (_released) return;
    _released = true;
    unawaited(MTOrientation.afterFullscreen());
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
    _release();
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
        listenable: Listenable.merge([
          session,
          MTPictureInPicture.instance.active,
        ]),
        builder: (context, _) {
          final controller = session.controller;
          // In a corner of the screen the picture shows alone.
          final inCorner = MTPictureInPicture.instance.active.value;
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
                  child: MTVideoFrame(
                    controller: controller,
                    item: session.current,
                    artwork: widget.artwork,
                  ),
                )
              else
                const Center(child: MTSpinner()),
              MTVideoControls(
                session: session,
                fullscreen: true,
                captions: switch (session.current) {
                  final item? => widget.captions?.call(item),
                  null => null,
                },
                chapters: switch (session.current) {
                  final item? => widget.chapters?.call(item) ?? const [],
                  null => const [],
                },
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
              _presence(
                context,
                open:
                    !inCorner &&
                    panel != null &&
                    _panelFor != null &&
                    _panelFor == session.current?.canonicalUrl,
                build: () => MTVideoEndPanel(
                  key: ValueKey(_panelFor),
                  child: panel!.builder(
                    context,
                    () => setState(() => _panelFor = null),
                  ),
                ),
              ),
              _presence(
                context,
                open: !inCorner && _queueOpen,
                build: () => _SidePanel(
                  session: session,
                  artwork: widget.artwork,
                  playlistName: widget.playlistName,
                  onShowAll: widget.onShowPlaylist == null
                      ? null
                      : () => _leaveThenShowPlaylist(context),
                  onClose: () => setState(() => _queueOpen = false),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A side panel that **fades out when closed** rather than vanishing in a
/// frame; it slides in on its own. Its own stack keeps the panel's
/// position valid inside the switcher.
Widget _presence(
  BuildContext context, {
  required bool open,
  required Widget Function() build,
}) => Positioned.fill(
  child: AnimatedSwitcher(
    duration: mtMotionDuration(context, MTMotion.medium),
    reverseDuration: mtMotionDuration(context, MTMotion.fast),
    transitionBuilder: (child, animation) =>
        FadeTransition(opacity: animation, child: child),
    child: open
        ? Stack(key: const ValueKey('open'), children: [build()])
        : const SizedBox.shrink(key: ValueKey('closed')),
  ),
);
