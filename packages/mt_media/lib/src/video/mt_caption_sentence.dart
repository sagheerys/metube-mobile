part of 'mt_captions.dart';

/// One sentence over its background, the word being said at full white and
/// the rest a step dimmer.
class _Sentence extends StatelessWidget {
  const _Sentence({
    super.key,
    required this.block,
    required this.word,
    required this.width,
    required this.size,
    required this.lines,
    required this.background,
  });

  final MTCaptionBlock block;
  final int word;
  final double width;
  final double size;
  final int lines;
  final MTCaptionBackground background;

  static const height = 1.35;
  static const maxLines = 3;

  /// The words not being said, against the one that is.
  static const _rest = 0.72;

  static BoxDecoration _capsule(double alpha) => BoxDecoration(
    color: MTPalette.serverCardBg.withValues(alpha: alpha),
    borderRadius: BorderRadius.circular(MTRadius.thumb + 4),
  );

  static final _soft = [
    Shadow(color: MTPalette.serverCardBg.withValues(alpha: 0.7), blurRadius: 4),
  ];

  /// Tight then wide: an edge round each letter, then a haze to lift it off
  /// a busy picture.
  static final _edge = [
    Shadow(
      color: MTPalette.serverCardBg.withValues(alpha: 0.95),
      blurRadius: 2,
    ),
    Shadow(color: MTPalette.serverCardBg.withValues(alpha: 0.8), blurRadius: 6),
  ];

  @override
  Widget build(BuildContext context) {
    final ink = MTPalette.serverCardInk;
    final (direction, _) = mtForeignLine(context, block.text);
    final style = Theme.of(context).textTheme.bodyLarge!.copyWith(
      fontSize: size,
      height: height,
      fontWeight: FontWeight.w500,
      color: ink,
      // With less behind them, the letters carry their own dark edge.
      shadows: switch (background) {
        MTCaptionBackground.solid => null,
        MTCaptionBackground.faint => _soft,
        MTCaptionBackground.none => _edge,
      },
    );
    final words = block.words;
    return Container(
      constraints: BoxConstraints(maxWidth: math.max(0, width * 0.88)),
      padding: const EdgeInsets.symmetric(
        horizontal: MTSpace.md,
        vertical: MTSpace.xs,
      ),
      decoration: switch (background) {
        MTCaptionBackground.solid => _capsule(0.78),
        MTCaptionBackground.faint => _capsule(0.4),
        MTCaptionBackground.none => null,
      },
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
        maxLines: lines,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
