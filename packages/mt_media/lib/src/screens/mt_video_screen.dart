import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player/video_player.dart';

import '../models/playlist_item.dart';
import '../video/mt_orientation.dart';
import '../video/mt_video_controls.dart';
import '../video/mt_video_fullscreen.dart';
import '../video/mt_video_session.dart';
import '../widgets/mt_queue_panel.dart';
import '../widgets/mt_up_next_list.dart';
import 'video_info_sheet.dart';

/// One action in the portrait player (offline, share, add to a list…).
/// The app supplies them, because mt_media knows neither the server nor
/// the indexes.
class MTPlayerAction {
  const MTPlayerAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlighted;
}

/// The portrait video player (Wahaj reference B): the video leads with a
/// cream sheet beneath it, running title, then actions, then mode, then
/// the "up next" list. Going back offers "continue as background audio?"
/// from the same second.
class MTVideoScreen extends StatelessWidget {
  const MTVideoScreen({
    super.key,
    required this.session,
    this.actions = const [],
    this.artwork,
    this.subtitleBuilder,
    this.onShowPlaylist,
    this.onContinueAsAudio,
    this.shouldOfferContinueAsAudio,
    this.playlistName,
    this.membershipLine,
  });

  final MTVideoSession session;
  final List<MTPlayerAction> actions;
  final MTArtworkBuilder? artwork;

  /// The meta line under the title (platform, uploader), supplied by the
  /// app.
  final String Function(BuildContext context, PlaylistItem item)?
      subtitleBuilder;
  final VoidCallback? onShowPlaylist;

  /// Smart handover: continue the same item as audio from the same second.
  /// **Awaited before closing the screen (defect ط-5):** it used to be
  /// called without awaiting and the player closed immediately, so the
  /// session provider was disposed (autoDispose) while the handover sat on
  /// an `await`. Either a `StateError` meant the audio never started, or
  /// `duration` became nothing, so a position near the end was **saved
  /// rather than cleared** and the clip "resumed" at the credits forever.
  final Future<void> Function(PlaylistItem item, Duration position)?
      onContinueAsAudio;

  /// **When the question is asked** (field report 2026-09-02: "after
  /// continuing in the background and pressing back the message appears; it
  /// should not"). The condition used to be `onContinueAsAudio == null`
  /// alone, so it asked on every exit, even after the user had already
  /// moved
  /// the clip to audio. Only the app knows the audio player's state, so the
  /// app decides.
  final bool Function()? shouldOfferContinueAsAudio;
  final String? playlistName;

  /// **Where the clip belongs** (field report 2026-09-04): "which tag it is
  /// under, or which playlist it was added to". Shown in landscape beneath
  /// the title; portrait shows it through [subtitleBuilder] in the info
  /// sheet.
  final String? membershipLine;

  bool get _offersAudio =>
      onContinueAsAudio != null &&
      (shouldOfferContinueAsAudio?.call() ?? true);

  /// **A tilt opens full screen and tilting back closes it** (decision
  /// 2026-09-05), and the button stays for anyone who has locked rotation
  /// in
  /// their system settings.
  @override
  Widget build(BuildContext context) => MTRotationScope(
        open: (byRotation) => _openFullscreen(context, byRotation),
        builder: (context, openFullscreen) => _body(context, openFullscreen),
      );

  Widget _body(BuildContext context, VoidCallback openFullscreen) => PopScope(
        canPop: !_offersAudio,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _askContinueAsAudio(context);
        },
        child: Scaffold(
          // **The system bar follows the theme** (field report 2026-09-05:
          // "the
          // clock bar is dark during the day and looks strange"). The video
          // itself
          // stays on a dark ground, but the bar above it took the page's
          // colour,
          // and that was "always dark", so a night bar appeared over a
          // cream
          // interface in daylight.
          backgroundColor: MTThemeX.of(context).palette.bg,
          body: ListenableBuilder(
            listenable: session,
            // **In landscape the video alone fills the screen** (field
            // report
            // 2026-09-05: "I leave full screen with the device in landscape
            // and the
            // app shows sideways"). Leaving manually disarms tilt so full
            // screen is
            // not reopened, and the result was a cream sheet with a
            // squeezed video on
            // a wide screen. Landscape is now **a form** of this screen
            // rather than a
            // fault in it.
            builder: (context, _) =>
                MediaQuery.orientationOf(context) == Orientation.landscape
                    ? _VideoArea(
                        session: session,
                        fill: true,
                        playlistName: playlistName,
                        membershipLine: membershipLine,
                        onBack: () => Navigator.of(context).maybePop(),
                        onFullscreen: openFullscreen,
                        onQueue: () => _openQueue(context),
                      )
                    : Column(
              children: [
                _VideoArea(
                  session: session,
                  playlistName: playlistName,
                  membershipLine: membershipLine,
                  onBack: () => Navigator.of(context).maybePop(),
                  onFullscreen: openFullscreen,
                  onQueue: () => _openQueue(context),
                ),
                Expanded(
                  child: MTVideoInfoSheet(
                    session: session,
                    actions: actions,
                    artwork: artwork,
                    subtitleBuilder: subtitleBuilder,
                    playlistName: playlistName,
                    onShowPlaylist: onShowPlaylist,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _openFullscreen(BuildContext context, bool byRotation) =>
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MTVideoFullscreenPage(
            session: session,
            byRotation: byRotation,
            artwork: artwork,
            playlistName: playlistName,
            membershipLine: membershipLine,
            onShowPlaylist: onShowPlaylist,
          ),
        ),
      );

  void _openQueue(BuildContext context) {
    final ordered = session.orderedItems;
    final currentUrl = session.current?.canonicalUrl;
    showMTQueueSheet(
      context,
      items: ordered,
      currentIndex: ordered.indexWhere((i) => i.canonicalUrl == currentUrl),
      artwork: artwork,
      playlistName: playlistName,
      // The session notifies on every tick, so the sheet knows when
      // playback
      // stopped.
      liveness: session,
      paused: () => !session.isPlaying,
      onShowAll: onShowPlaylist,
      onSelect: (index) =>
          session.jumpTo(session.items.indexOf(ordered[index])),
    );
  }

  /// The smart handover dialog on exit.
  Future<void> _askContinueAsAudio(BuildContext context) async {
    final item = session.current;
    final navigator = Navigator.of(context);
    // **We only pop our own page** (field report 2026-09-03): the handover
    // to
    // audio can take a while, and the user may have left another way in the
    // meantime, so a blind `pop()` afterwards popped **the shell itself**
    // and
    // nothing was left: a black screen.
    final route = ModalRoute.of(context);
    void popSelf() {
      if (route == null || route.isCurrent) navigator.pop();
    }

    if (item == null) return popSelf();
    final position = session.position;
    await session.savePosition();
    if (!context.mounted) return;
    final l10n = context.mtl;

    final choice = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.continueAsAudioTitle),
        content: Text(l10n.continueAsAudioBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.continueAsAudioNo),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.continueAsAudio),
          ),
        ],
      ),
    );
    if (choice == true) await onContinueAsAudio?.call(item, position);
    popSelf();
  }
}

class _VideoArea extends StatelessWidget {
  const _VideoArea({
    required this.session,
    required this.onBack,
    required this.onFullscreen,
    required this.onQueue,
    this.playlistName,
    this.membershipLine,
    this.fill = false,
  });

  /// Fills the screen in landscape instead of 32% of its height.
  final bool fill;

  final MTVideoSession session;
  final VoidCallback onBack;
  final VoidCallback onFullscreen;
  final VoidCallback onQueue;
  final String? playlistName;
  final String? membershipLine;

  @override
  Widget build(BuildContext context) {
    final controller = session.controller;
    final ready = controller != null && controller.value.isInitialized;
    return SafeArea(
      bottom: false,
      child: SizedBox(
        height: fill
            ? double.infinity
            : MediaQuery.sizeOf(context).height * 0.32,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: MTPalette.serverCardBg),
            if (ready)
              Center(
                child: AspectRatio(
                  aspectRatio: controller.value.aspectRatio,
                  child: VideoPlayer(controller),
                ),
              )
            else
              Center(
                child: session.error != null
                    ? Icon(Icons.error_outline_rounded,
                        color: MTPalette.serverCardInk)
                    : const CircularProgressIndicator(),
              ),
            if (ready)
              MTVideoControls(
                session: session,
                playlistName: playlistName,
                membershipLine: membershipLine,
                onBack: onBack,
                onToggleFullscreen: onFullscreen,
                onQueue: onQueue,
              ),
          ],
        ),
      ),
    );
  }
}
