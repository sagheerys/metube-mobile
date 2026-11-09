import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player/video_player.dart';

import 'mt_caption_blocks.dart';
import 'mt_caption_clock.dart';
import 'mt_caption_data.dart';

export 'mt_caption_blocks.dart' show MTCaptionBlock;
export 'mt_caption_clock.dart';
export 'mt_caption_data.dart';

part 'mt_caption_sentence.dart';

/// The captions over a playing video, above its controls when they show.
///
/// **On time, not half a second late**: the player reports its position
/// about twice a second, so the moment between two reports is worked out
/// from the last one and the speed, and the word lights as it is said.
class MTCaptionsLayer extends StatefulWidget {
  const MTCaptionsLayer({
    super.key,
    this.controller,
    this.clock,
    required this.captions,
    required this.lift,
    this.clearCenter = false,
    this.tapToSwitch = false,
  });

  /// The phones' player; or any [clock], as the Windows app's. One of
  /// the two.
  final VideoPlayerController? controller;
  final MTCaptionClock? clock;
  final MTCaptions captions;

  /// The room kept free at the bottom, for the controls when they show.
  final double lift;

  /// The play button sits in the middle while the controls show: the
  /// sentence keeps below it, in fewer lines, or waits for the controls to
  /// fade where a small player leaves no room between the two.
  final bool clearCenter;

  /// **The sentence itself switches the language**, with the language's
  /// code beside it. For the shorts alone,
  /// which have no CC bar to hold a button; everywhere else the layer lets
  /// every touch through to the player beneath.
  final bool tapToSwitch;

  @override
  State<MTCaptionsLayer> createState() => _MTCaptionsLayerState();
}

class _MTCaptionsLayerState extends State<MTCaptionsLayer>
    with SingleTickerProviderStateMixin {
  late MTCaptionClock _time = _clockOf(widget);
  late List<MTCaptionBlock> _blocks = MTCaptionBlock.group(
    widget.captions.onScreen,
  );
  late final Ticker _ticker = createTicker((_) => _update());
  final _clock = Stopwatch()..start();
  Duration _anchor = Duration.zero;
  Duration _anchoredAt = Duration.zero;
  int _block = -1;
  int _word = -1;

  /// Never runs further than this past the last report: a stall the
  /// player has not reported yet must not race the words ahead.
  static const _reach = Duration(milliseconds: 900);

  /// Half the height of the play button and its seek neighbours, with a
  /// little air.
  static const _centerHalf = 44.0;

  @override
  void initState() {
    super.initState();
    _time.addListener(_onPlayer);
    widget.captions.shown.addListener(_onPlayer);
    widget.captions.language?.addListener(_onLanguage);
    _onPlayer();
  }

  /// Another language: its sentences, from the same moment. Redrawn
  /// whatever [_update] finds, since the old sentence is on screen even
  /// when the new language has nothing at this moment.
  void _onLanguage() {
    setState(() {
      _blocks = MTCaptionBlock.group(widget.captions.onScreen);
      _block = -1;
      _word = -1;
    });
    _update();
  }

  @override
  void didUpdateWidget(MTCaptionsLayer old) {
    super.didUpdateWidget(old);
    if (!identical(old.captions.onScreen, widget.captions.onScreen)) {
      _blocks = MTCaptionBlock.group(widget.captions.onScreen);
    }
    if (old.captions.language != widget.captions.language) {
      old.captions.language?.removeListener(_onLanguage);
      widget.captions.language?.addListener(_onLanguage);
    }
    final time = _clockOf(widget);
    if (time != _time) {
      _time.removeListener(_onPlayer);
      _time = time..addListener(_onPlayer);
    }
    if (old.captions.shown != widget.captions.shown) {
      old.captions.shown.removeListener(_onPlayer);
      widget.captions.shown.addListener(_onPlayer);
    }
    _onPlayer();
  }

  @override
  void dispose() {
    _time.removeListener(_onPlayer);
    widget.captions.shown.removeListener(_onPlayer);
    widget.captions.language?.removeListener(_onLanguage);
    _ticker.dispose();
    super.dispose();
  }

  static MTCaptionClock _clockOf(MTCaptionsLayer layer) =>
      layer.clock ?? VideoCaptionClock(layer.controller!);

  void _onPlayer() {
    _anchor = _time.position;
    _anchoredAt = _clock.elapsed;
    final moving = _time.running && widget.captions.shown.value;
    if (moving && !_ticker.isActive) _ticker.start();
    if (!moving && _ticker.isActive) _ticker.stop();
    _update();
  }

  Duration get _now {
    if (!_time.running) return _anchor;
    final since = _clock.elapsed - _anchoredAt;
    final ahead = since * _time.speed;
    return _anchor + (ahead > _reach ? _reach : ahead);
  }

  void _update() {
    if (!mounted) return;
    final at = _now;
    final block = MTCaptionBlock.indexAt(_blocks, at);
    final word = block < 0 ? -1 : _blocks[block].wordAt(at);
    if (block != _block || word != _word) {
      setState(() {
        _block = block;
        _word = word;
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.captions.restyled,
    builder: (context, _) => IgnorePointer(
      // Only the sentence takes a touch; the space around it is empty and
      // lets taps reach the player.
      ignoring: !(widget.tapToSwitch && widget.captions.switchable),
      child: LayoutBuilder(
        builder: (context, box) {
          // In step with the picture: larger on a tablet and in full screen.
          final size =
              (box.maxWidth * 0.038).clamp(13.0, 22.0) *
              widget.captions.scaleNow;
          final shown = widget.captions.shown.value;
          final line =
              MediaQuery.textScalerOf(context).scale(size) * _Sentence.height;
          var lines = _Sentence.maxLines;
          if (widget.clearCenter) {
            final room =
                box.maxHeight / 2 - _centerHalf - widget.lift - 2 * MTSpace.xs;
            lines = math.min(lines, room ~/ line);
          }
          return AnimatedPadding(
            duration: MTMotion.fast,
            curve: MTMotion.ease,
            padding: EdgeInsets.only(
              bottom: widget.lift,
              left: MTSpace.lg,
              right: MTSpace.lg,
            ),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: AnimatedSwitcher(
                duration: MTMotion.fast,
                child: !shown || _block < 0 || lines < 1
                    ? const SizedBox.shrink()
                    : _SentenceSwitch(
                        key: ValueKey(_block),
                        captions: widget.captions,
                        enabled: widget.tapToSwitch,
                        size: size,
                        child: _Sentence(
                          key: ValueKey(_block),
                          block: _blocks[_block],
                          word: _word,
                          width: box.maxWidth,
                          size: size,
                          lines: lines,
                          background: widget.captions.backgroundNow,
                        ),
                      ),
              ),
            ),
          );
        },
      ),
    ),
  );
}
