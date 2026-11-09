import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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

/// What sits behind the words: a dark capsule, a faint one, or nothing but
/// a shadow around the letters, which keeps them legible over a bright
/// picture.
enum MTCaptionBackground { solid, faint, none }

/// Captions for the clip on screen: its lines, whether they are shown, how
/// large, and over what. [shown] and [language] belong to the app, which
/// keeps the choices.
class MTCaptions {
  const MTCaptions({
    required this.lines,
    required this.shown,
    this.scale = 1,
    this.background = MTCaptionBackground.solid,
    this.tracks = const {},
    this.language,
    this.liveScale,
    this.liveBackground,
    this.onAdjust,
  });

  /// The lines shown when no other language is chosen.
  final List<MTCaptionLine> lines;
  final ValueNotifier<bool> shown;
  final double scale;
  final MTCaptionBackground background;

  /// Every language the clip has, by code, in the order the switch walks
  /// them, the first being [lines]. Empty for a clip with one.
  final Map<String, List<MTCaptionLine>> tracks;

  /// The language chosen with the switch, kept by the app from clip to
  /// clip. Null, or a language this clip lacks, shows [lines].
  final ValueNotifier<String?>? language;

  /// The size and background as the app keeps them, when they can change
  /// while the clip plays; each wins over [scale] and [background].
  final ValueListenable<double>? liveScale;
  final ValueListenable<MTCaptionBackground>? liveBackground;

  /// Opens the app's own size and background choices, from a long press
  /// on CC: changed over the picture, without leaving the clip for
  /// settings. Null leaves CC with its tap alone.
  final void Function(BuildContext context)? onAdjust;

  double get scaleNow => liveScale?.value ?? scale;
  MTCaptionBackground get backgroundNow => liveBackground?.value ?? background;

  /// Fires when what is drawn changes: shown or hidden, its size, its
  /// background.
  Listenable get restyled =>
      Listenable.merge([shown, liveScale, liveBackground]);

  /// The language on screen, for the switch's label.
  String? get current {
    final chosen = language?.value;
    if (chosen != null && tracks.containsKey(chosen)) return chosen;
    return tracks.isEmpty ? null : tracks.keys.first;
  }

  /// The lines on screen.
  List<MTCaptionLine> get onScreen => tracks[current] ?? lines;

  /// Whether the switch has anything to switch to.
  bool get switchable => language != null && tracks.length > 1;

  /// The next language round the clip's list.
  void nextLanguage() {
    if (!switchable) return;
    final codes = tracks.keys.toList();
    language!.value = codes[(codes.indexOf(current!) + 1) % codes.length];
  }
}
