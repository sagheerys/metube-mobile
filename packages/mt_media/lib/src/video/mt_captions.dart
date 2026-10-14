import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:video_player/video_player.dart';

import 'mt_caption_blocks.dart';

export 'mt_caption_blocks.dart' show MTCaptionBlock;

/// One word of a caption line, from the moment it is said.
class MTCaptionWord {
  const MTCaptionWord(this.start, this.text);

  final Duration start;
  final String text;
}

/// A timed line the app hands a player to draw over the picture. This
/// package knows nothing of where it came from (a transcript, in Super).
class MTCaptionLine {
  const MTCaptionLine({
    required this.start,
    required this.end,
    required this.text,
    this.words,
  });

  final Duration start;
  final Duration end;
  final String text;

  /// When each word is said, where the subtitles tell it; null shows the
  /// line whole.
  final List<MTCaptionWord>? words;
}

/// Captions for the clip on screen: its lines, whether they are shown, and
/// how large. [shown] belongs to the app, which keeps the choice.
class MTCaptions {
  const MTCaptions({required this.lines, required this.shown, this.scale = 1});

  final List<MTCaptionLine> lines;
  final ValueNotifier<bool> shown;
  final double scale;
}

/// The captions over a playing video, above its controls when they show.
///
/// **On time, not half a second late**: the player reports its position
/// about twice a second, so the moment between two reports is worked out
/// from the last one and the speed, and the word lights as it is said.
class MTCaptionsLayer extends StatefulWidget {
  const MTCaptionsLayer({
    super.key,
    required this.controller,
    required this.captions,
    required this.lift,
  });

  final VideoPlayerController controller;
  final MTCaptions captions;

  /// The room kept free at the bottom, for the controls when they show.
  final double lift;

  @override
  State<MTCaptionsLayer> createState() => _MTCaptionsLayerState();
}

class _MTCaptionsLayerState extends State<MTCaptionsLayer>
    with SingleTickerProviderStateMixin {
  late List<MTCaptionBlock> _blocks = MTCaptionBlock.group(
    widget.captions.lines,
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

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onPlayer);
    widget.captions.shown.addListener(_onPlayer);
    _onPlayer();
  }

  @override
  void didUpdateWidget(MTCaptionsLayer old) {
    super.didUpdateWidget(old);
    if (!identical(old.captions.lines, widget.captions.lines)) {
      _blocks = MTCaptionBlock.group(widget.captions.lines);
    }
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onPlayer);
      widget.controller.addListener(_onPlayer);
    }
    if (old.captions.shown != widget.captions.shown) {
      old.captions.shown.removeListener(_onPlayer);
      widget.captions.shown.addListener(_onPlayer);
    }
    _onPlayer();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onPlayer);
    widget.captions.shown.removeListener(_onPlayer);
    _ticker.dispose();
    super.dispose();
  }

  void _onPlayer() {
    final value = widget.controller.value;
    _anchor = value.position;
    _anchoredAt = _clock.elapsed;
    final moving =
        value.isPlaying && !value.isBuffering && widget.captions.shown.value;
    if (moving && !_ticker.isActive) _ticker.start();
    if (!moving && _ticker.isActive) _ticker.stop();
    _update();
  }

  Duration get _now {
    final value = widget.controller.value;
    if (!value.isPlaying || value.isBuffering) return _anchor;
    final since = _clock.elapsed - _anchoredAt;
    final ahead = since * value.playbackSpeed;
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
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: widget.captions.shown,
    builder: (context, shown, _) => IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) => AnimatedPadding(
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
              child: !shown || _block < 0
                  ? const SizedBox.shrink()
                  : _Sentence(
                      key: ValueKey(_block),
                      block: _blocks[_block],
                      word: _word,
                      width: box.maxWidth,
                      scale: widget.captions.scale,
                    ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// One sentence in its capsule, the word being said at full white and the
/// rest a step dimmer.
class _Sentence extends StatelessWidget {
  const _Sentence({
    super.key,
    required this.block,
    required this.word,
    required this.width,
    required this.scale,
  });

  final MTCaptionBlock block;
  final int word;
  final double width;
  final double scale;

  /// The words not being said, against the one that is.
  static const _rest = 0.72;

  @override
  Widget build(BuildContext context) {
    final ink = MTPalette.serverCardInk;
    final (direction, _) = mtForeignLine(context, block.text);
    // In step with the picture: larger on a tablet and in full screen.
    final size = (width * 0.042).clamp(14.0, 26.0) * scale;
    final style = Theme.of(context).textTheme.bodyLarge!.copyWith(
      fontSize: size,
      height: 1.35,
      fontWeight: FontWeight.w500,
      color: ink,
    );
    final words = block.words;
    return Container(
      constraints: BoxConstraints(maxWidth: math.max(0, width * 0.88)),
      padding: const EdgeInsets.symmetric(
        horizontal: MTSpace.md,
        vertical: MTSpace.xs,
      ),
      decoration: BoxDecoration(
        color: MTPalette.serverCardBg.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(MTRadius.thumb + 4),
      ),
      child: Text.rich(
        words == null
            ? TextSpan(text: block.text)
            : TextSpan(
                children: [
                  for (var i = 0; i < words.length; i++)
                    TextSpan(
                      text: i == 0 ? words[i].text : ' ${words[i].text}',
                      style: TextStyle(
                        color: ink.withValues(
                          alpha: i == word || word < 0 ? 1 : _rest,
                        ),
                      ),
                    ),
                ],
              ),
        style: style,
        textAlign: TextAlign.center,
        textDirection: direction,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
