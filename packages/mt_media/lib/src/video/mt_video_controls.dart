import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../widgets/mt_extra_button.dart';
import '../widgets/mt_chapters.dart';
import 'mt_captions.dart';
import 'mt_picture_in_picture.dart';
import 'mt_video_session.dart';
import 'video_buttons.dart';
import 'video_center_controls.dart';
import 'video_control_bars.dart';

/// The video chrome over the clip (Wahaj reference C): a touch shows it
/// and three seconds hide it, a double tap on the right or left seeks ten
/// seconds, and there is a touch lock in immersive mode.
class MTVideoControls extends StatefulWidget {
  const MTVideoControls({
    super.key,
    required this.session,
    required this.onBack,
    required this.onToggleFullscreen,
    required this.onQueue,
    this.fullscreen = false,
    this.playlistName,
    this.membershipLine,
    this.extra,
    this.captions,
    this.chapters = const [],
  });

  final MTVideoSession session;
  final VoidCallback onBack;
  final VoidCallback onToggleFullscreen;
  final VoidCallback onQueue;

  /// A button the app adds beside the queue button.
  final MTExtraAction? extra;
  final bool fullscreen;

  /// The clip's subtitles, drawn under the controls and above them when
  /// they show; null for a clip without any.
  final MTCaptions? captions;
  final String? playlistName;
  final String? membershipLine;

  /// The clip's chapters, on the progress bar and beside the time.
  final List<MTChapter> chapters;

  @override
  State<MTVideoControls> createState() => _MTVideoControlsState();
}

class _MTVideoControlsState extends State<MTVideoControls> {
  static const Duration _hideAfter = Duration(seconds: 3);

  bool _visible = true;
  bool _locked = false;
  Timer? _hideTimer;

  MTPictureInPicture get _pip => MTPictureInPicture.instance;

  @override
  void initState() {
    super.initState();
    _restartTimer();
    widget.session.addListener(_reportPlaying);
  }

  /// Here rather than in [initState]: the window's button takes its names
  /// from the user's language, which may change while the player is open.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reportPlaying();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    widget.session.removeListener(_reportPlaying);
    _pip.detach(this);
    super.dispose();
  }

  /// While a video plays on screen, leaving the app may move it to a
  /// corner (when the user has turned that on).
  void _reportPlaying() => _pip.attach(
    this,
    playing: widget.session.isPlaying,
    aspect: mtPictureShape(widget.session),
    button: (
      toggle: widget.session.playPause,
      play: context.mtl.play,
      pause: context.mtl.pause,
    ),
  );

  void _restartTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(_hideAfter, () {
      if (mounted && widget.session.isPlaying) setState(() => _visible = false);
    });
  }

  void _toggleVisible() {
    setState(() => _visible = !_visible);
    if (_visible) _restartTimer();
  }

  void _onDoubleTap(TapDownDetails details, BoxConstraints constraints) {
    if (_locked) return;
    // The left half goes back in every language: the timeline under it
    // runs left to right (see MTProgressSlider), as YouTube's does.
    final backward = details.localPosition.dx < constraints.maxWidth / 2;
    widget.session.seekBy(Duration(seconds: backward ? -10 : 10));
    _restartTimer();
  }

  /// Clear of the bottom bar while it shows, near the edge when it hides:
  /// above the light sheet, which overlaps the small player by 14px.
  double get _captionLift => _visible && !_locked
      ? _barBottom + _barHeight + MTSpace.xs
      : (widget.fullscreen ? MTSpace.lg : MTSpace.xxl);

  /// The slider's track sits in the middle of its 32: from here it is 20
  /// above the video's bottom, 6 clear of the light sheet over it.
  double get _barBottom => widget.fullscreen ? 0 : MTSpace.xxs;

  /// The bottom bar's row of 32-high buttons and its 32-high slider, which
  /// prints no times of its own: the row above shows them.
  static const double _barHeight = 64;

  /// In a corner of the screen the picture shows alone: no control fits
  /// there, and the system draws its own.
  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: _pip.active,
    builder: (context, inCorner, _) =>
        inCorner ? const SizedBox.shrink() : _layers(),
  );

  Widget _layers() => Stack(
    fit: StackFit.expand,
    children: [
      if ((widget.captions, widget.session.controller) case (
        final captions?,
        final controller?,
      ))
        MTCaptionsLayer(
          controller: controller,
          captions: captions,
          lift: _captionLift,
          clearCenter: _visible && !_locked,
        ),
      _controls(),
    ],
  );

  Widget _controls() => LayoutBuilder(
    builder: (context, constraints) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleVisible,
      onDoubleTapDown: (d) => _onDoubleTap(d, constraints),
      onDoubleTap: () {},
      child: AnimatedOpacity(
        opacity: _visible ? 1 : 0,
        duration: MTMotion.fast,
        curve: MTMotion.ease,
        child: IgnorePointer(
          ignoring: !_visible,
          child: _locked ? _lockedLayer() : _controlsLayer(),
        ),
      ),
    ),
  );

  Widget _lockedLayer() => Center(
    child: MTVideoIconButton(
      icon: MTIcons.unlock,
      tooltip: context.mtl.unlockTouch,
      onTap: () {
        setState(() => _locked = false);
        _restartTimer();
      },
    ),
  );

  Widget _controlsLayer() => Stack(
    children: [
      const Positioned.fill(child: _Scrim()),
      PositionedDirectional(
        top: MTSpace.sm,
        start: MTSpace.md,
        end: MTSpace.md,
        child: MTVideoTopBar(
          session: widget.session,
          onBack: widget.onBack,
          onToggleFullscreen: widget.onToggleFullscreen,
          fullscreen: widget.fullscreen,
          playlistName: widget.playlistName,
          membershipLine: widget.membershipLine,
          captions: widget.captions,
          onLock: widget.fullscreen
              ? () {
                  _hideTimer?.cancel();
                  setState(() => _locked = true);
                }
              : null,
        ),
      ),
      Positioned.fill(
        child: Center(child: MTVideoCenterControls(session: widget.session)),
      ),
      PositionedDirectional(
        // In full screen the thin bar rests on the screen's bottom edge;
        // under the video, just above the details sheet, whose rounded
        // top overlaps the video by 14px.
        bottom: _barBottom,
        // Under the video the bar runs edge to edge, as the picture does;
        // full screen keeps a margin, so a phone's rounded corners do not
        // cut its ends.
        start: widget.fullscreen ? MTSpace.md : 0,
        end: widget.fullscreen ? MTSpace.md : 0,
        child: MTVideoBottomBar(
          rowInset: widget.fullscreen ? 0 : MTSpace.md,
          session: widget.session,
          onQueue: widget.onQueue,
          extra: widget.extra,
          chapters: widget.chapters,
          onChapters: () => showMTChapterSheet(
            context,
            chapters: widget.chapters,
            ticks: widget.session,
            position: () => widget.session.position,
            onSeek: widget.session.seek,
          ),
        ),
      ),
    ],
  );
}

/// A top and bottom gradient separating the chrome from the picture, from
/// the reference.
class _Scrim extends StatelessWidget {
  const _Scrim();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black.withValues(alpha: 0.5),
          Colors.transparent,
          Colors.transparent,
          Colors.black.withValues(alpha: 0.6),
        ],
        stops: const [0, 0.28, 0.6, 1],
      ),
    ),
  );
}
