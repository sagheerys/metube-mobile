import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/playback_source.dart';
import '../models/playlist_item.dart';
import '../video/mt_orientation.dart';
import '../video/reels_overlay.dart';
import '../video/reels_progress.dart';
import '../video/reels_stage.dart';
import '../video/shorts_lane.dart';
import 'mt_video_screen.dart';

part 'mt_reels_player_controls.dart';

/// **The reels player**: immersive, with a vertical swipe, inside the
/// shorts path only. Portrait shorts from the list on screen in the same
/// order; audio and landscape items are skipped silently, and the counter
/// counts shorts alone.
///
/// The clip **loops** until a swipe, and no resume position is saved for
/// it. A tap toggles play and pause, a double tap favourites, and there is
/// a side column of actions.
class MTReelsPlayer extends StatefulWidget {
  const MTReelsPlayer({
    super.key,
    required this.lane,
    required this.resolver,
    this.startIndex = 0,
    this.isFavorite,
    this.onToggleFavorite,
    this.onDoubleTapFavorite,
    this.actionsBuilder,
    this.subtitleBuilder,
    this.onContinueRest,
    this.onTakeAudioFocus,
    this.onLive,
  });

  final ShortsLane lane;
  final PlaybackSourceResolver resolver;
  final int startIndex;
  final bool Function(PlaylistItem item)? isFavorite;

  /// **The heart button in the side column.** `null` means it is not shown
  /// at all. Requested 2026-09-04: the "add to…" button covers it.
  final void Function(PlaylistItem item)? onToggleFavorite;

  /// **The double tap** stays the favourite shortcut even when the heart is
  /// gone from the column. When it is not supplied, [onToggleFavorite] is
  /// used as before.
  final void Function(PlaylistItem item)? onDoubleTapFavorite;
  final List<MTPlayerAction> Function(PlaylistItem item)? actionsBuilder;
  final String Function(BuildContext context, PlaylistItem item)?
  subtitleBuilder;

  /// Stops the background audio player before the first play, or the audio
  /// and the reel run together.
  final VoidCallback? onContinueRest;

  /// Stops the background audio player before the first play, or the audio
  /// and the reel run together.
  final Future<void> Function()? onTakeAudioFocus;

  /// **The opposite direction of the golden rule (defect ع-4).** It hands
  /// upwards a "stopper for this player" while alive and `null` once dead,
  /// so the audio player can silence the reel before it plays. Without
  /// this, one play press in the media notification produced **two sources
  /// at once**.
  final void Function(Future<void> Function()? pauser)? onLive;

  @override
  State<MTReelsPlayer> createState() => _MTReelsPlayerState();
}

class _MTReelsPlayerState extends State<MTReelsPlayer> {
  late final PageController _pages = PageController(
    initialPage: widget.startIndex,
  );
  VideoPlayerController? _controller;
  late int _index = widget.startIndex;
  bool _endReached = false;
  bool _failed = false;

  /// **The chrome hides after a moment** (requested 2026-09-02). One rule
  /// with no hidden modes: any touch shows the chrome **and toggles
  /// playback**, then it hides after [_chromeLinger] if the clip is still
  /// running. Pausing pins it: someone who paused wants to read and act,
  /// not
  /// watch.
  int _generation = 0;

  /// **The chrome hides after a moment** (requested 2026-09-02). One rule
  /// with no hidden modes: any touch shows the chrome **and toggles
  /// playback**, then it hides after [_chromeLinger] if the clip is still
  /// running. Pausing pins it: someone who paused wants to read and act,
  /// not watch.
  static const _chromeLinger = Duration(seconds: 3);
  bool _chrome = true;
  Timer? _hideTimer;

  /// **The screen used to switch off while watching** (field report
  /// 2026-09-02): `MTVideoSession` holds the wake lock, but reels owns its
  /// raw controller directly, so nobody held it here at all.
  bool _wakelockOn = false;

  /// **The death flag — and it is never replaced by `mounted`** (a field
  /// defect, 2026-09-03, proven with a trace on the device).
  ///
  /// `State.mounted` is `_element != null`, and the framework clears
  /// `_element` **after** `dispose()` returns. So if any line inside
  /// `dispose()` throws, and one did, `onLive` below, it was never cleared,
  /// and **`mounted` stayed true forever on a dead screen**. The pending
  /// load then passed every `mounted` guard, played a clip and handed it to
  /// a field nobody would ever dispose: audio running behind the app with
  /// no mini player and no way to stop it (field report).
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    // **The status bar stays visible** (field report 2026-09-02): Instagram
    // and TikTok extend the video behind the bar without hiding it. The
    // clock and the battery belong to the user, and `immersiveSticky`
    // swallowed them and made an edge swipe summon the bar instead of
    // changing clip.
    //
    // Its icon colour is set through `AnnotatedRegion` in `build` rather
    // than here; see the comment there, since that reason is proven with
    // `dumpsys` rather than inferred.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // **Reels is always portrait and never pauses on tilt** (decision
    // 2026-09-05): the content is 9:16, and rotating it gives two black
    // bars and a small clip in the middle. TikTok and Shorts both ignore
    // rotation here. And pausing on a tilt punishes a movement nobody
    // intended.
    MTOrientation.lockPortrait();
    _notifyLive(_pauseForAudioFocus);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(_index));
  }

  /// `setState` is protected and cannot be called from an extension even in
  /// the same library. This is its only window into the commands `part`
  /// file, the same pattern as `MTVideoSession.notifyFromCommands`.
  void applyState(VoidCallback fn) => setState(fn);

  /// **The host callback is shielded**: `onLive` usually reaches `ref` in
  /// the host app, and `ref.read` from a `ConsumerState` after invalidation
  /// **throws**. One throw inside `dispose()` used to abort everything
  /// after it (see [_disposed]).
  void _notifyLive(Future<void> Function()? pauser) {
    try {
      widget.onLive?.call(pauser);
    } on Object catch (error) {
      debugPrint('MTReelsPlayer: onLive threw — $error');
    }
  }

  /// Returns the system icons to whatever the theme decides; reels alone is
  /// always dark.
  @override
  void dispose() {
    _disposed = true;
    _generation++; // a pending load plays nothing after this moment
    _hideTimer?.cancel();
    final controller = _controller;
    _controller = null;
    if (controller != null) unawaited(_shutdownController(controller));
    unawaited(_setWakelock(false));
    _pages.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    // Returns the system icons to whatever the theme decides; reels alone
    // is always dark.
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.light);
    _notifyLive(null);
    super.dispose();
  }

  PlaylistItem? get _current => _index >= 0 && _index < widget.lane.length
      ? widget.lane.items[_index]
      : null;

  void _onPageChanged(int page) {
    if (_disposed) return;
    if (page >= widget.lane.length) {
      setState(() {
        _endReached = true;
        _chrome = true;
      });
      _hideTimer?.cancel();
      _controller?.pause();
      unawaited(_setWakelock(false));
      return;
    }
    setState(() {
      _index = page;
      _endReached = false;
    });
    _load(page);
  }

  /// **Scrubbing goes through the state owner (defect ط-3).** The scrubber
  /// used to call `controller.play()` directly, the only call in the
  /// package with no audio focus and no wake-lock accounting: resuming
  /// after a scrub let the screen sleep during playback, and the background
  /// audio came back so two sources were heard.
  bool _resumeAfterScrub = false;

  @override
  Widget build(BuildContext context) {
    final item = _current;
    // **The bar was present and unreadable** (field report "it covers the
    // top bar", diagnosed with `dumpsys window` 2026-09-02): `vsysui=…
    // LIGHT_STATUS_BAR`, meaning the system was drawing its icons **black**
    // because the daylight theme is cream, on top of the black reels
    // background. The result was a bar that existed and showed nothing: the
    // clock and battery were black on black (pixel measurement: the entire
    // top row was 0,0,0).
    //
    // And `SystemChrome.setSystemUIOverlayStyle` in `initState` is not
    // enough: the framework re-imposes the overlay style every frame from
    // the topmost `AnnotatedRegion` in the tree, so a value set once is
    // overwritten. The `AnnotatedRegion` here takes part in that decision
    // every frame and wins because it is the topmost.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pages,
              scrollDirection: Axis.vertical,
              // One extra page is the "shorts finished" card, shown after the
              // swipe bounces.
              itemCount: widget.lane.length + 1,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, page) => page >= widget.lane.length
                  ? const SizedBox.expand()
                  : ReelsVideoLayer(
                      controller: page == _index ? _controller : null,
                      failed: page == _index && _failed,
                      onTap: _togglePlay,
                      onDoubleTap: () {
                        final target = widget.lane.items[page];
                        // A double tap is a blind gesture, so the pulse is
                        // the only confirmation that the toggle actually
                        // happened.
                        HapticFeedback.selectionClick();
                        (widget.onDoubleTapFavorite ?? widget.onToggleFavorite)
                            ?.call(target);
                        setState(() {});
                      },
                    ),
            ),
            if (_endReached)
              MTReelsEndCard(
                onBack: () => Navigator.of(context).maybePop(),
                onContinueRest: widget.onContinueRest,
                onReplay: () {
                  _pages.jumpToPage(0);
                  _onPageChanged(0);
                },
              )
            else if (item != null) ...[
              ReelsOverlayLayer(
                item: item,
                index: _index,
                total: widget.lane.length,
                favorite: widget.isFavorite?.call(item) ?? false,
                onToggleFavorite: widget.onToggleFavorite == null
                    ? null
                    : () {
                        widget.onToggleFavorite!(item);
                        setState(() {});
                        _showChrome();
                      },
                actions: widget.actionsBuilder?.call(item) ?? const [],
                subtitle: widget.subtitleBuilder?.call(context, item),
                visible: _chrome,
              ),
              // **The scrubber alone is always visible** (requested): it is
              // the only reference for where you are in the clip, and hiding
              // it with the chrome makes seeking impossible without two
              // touches. So it lives **outside** the fading chrome layer.
              PositionedDirectional(
                start: MTSpace.lg,
                end: MTSpace.lg,
                bottom: MTSpace.sm,
                child: SafeArea(
                  top: false,
                  child: ReelsProgressBar(
                    controller: _controller,
                    onScrubStart: _onScrubStart,
                    onScrubEnd: () => unawaited(_onScrubEnd()),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
