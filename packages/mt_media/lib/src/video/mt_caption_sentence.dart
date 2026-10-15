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

/// The sentence as the language switch: its code at the line's end, a tap
/// anywhere on it for the next language. Itself alone while switching is
/// off, or the clip has one language.
class _SentenceSwitch extends StatelessWidget {
  const _SentenceSwitch({
    super.key,
    required this.captions,
    required this.enabled,
    required this.size,
    required this.child,
  });

  final MTCaptions captions;
  final bool enabled;
  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled || !captions.switchable) return child;
    return Semantics(
      button: true,
      label: context.mtl.subtitlesLanguage,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: captions.nextLanguage,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: child),
            const SizedBox(width: MTSpace.xs),
            _LanguageTag(code: captions.current ?? '', size: size),
          ],
        ),
      ),
    );
  }
}

/// The language on screen as its short code, in the sentence's own dark,
/// at half its size.
class _LanguageTag extends StatelessWidget {
  const _LanguageTag({required this.code, required this.size});

  final String code;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
      horizontal: MTSpace.xs + 2,
      vertical: 2,
    ),
    decoration: _Sentence._capsule(0.78),
    child: Text(
      code.split('-').first.toUpperCase(),
      style: Theme.of(context).textTheme.labelSmall!.copyWith(
        fontSize: size * 0.55,
        fontWeight: FontWeight.w700,
        color: MTPalette.serverCardInk,
      ),
    ),
  );
}
