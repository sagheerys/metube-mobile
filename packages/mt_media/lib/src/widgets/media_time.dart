import 'package:mt_ui/mt_ui.dart';

import '../models/play_mode.dart';

/// Time formatting in the players: tabular digits, untranslated, the same
/// shape in every language.
String mtFormatDuration(Duration d) {
  final total = d.isNegative ? Duration.zero : d;
  final hours = total.inHours;
  final minutes = total.inMinutes.remainder(60);
  final seconds = total.inSeconds.remainder(60);
  final mm = hours > 0 ? minutes.toString().padLeft(2, '0') : '$minutes';
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

/// The remaining time as `-12:30`, as in the audio screen reference.
///
/// **Direction-isolated**: the minus sign is a neutral character, so in an
/// Arabic paragraph it moved to the end of the string and read as
/// "50:49-" (screenshot 2026-09-05).
String mtFormatRemaining(Duration position, Duration? total) {
  if (total == null || total <= Duration.zero) return '--:--';
  return mtLtrRun('-${mtFormatDuration(total - position)}');
}

/// Playback speed: `1.0` rather than `1`, and `1.25` rather than `1.250`.
/// The audio and video players share it, so the number never looks
/// different on two screens showing the same setting.
String mtFormatSpeed(double speed) =>
    speed == speed.roundToDouble() ? speed.toStringAsFixed(1) : '$speed';

/// The next speed in the cycle. **It used to be copied three times**: the
/// audio screen, the video info sheet, and the new speed button. Three
/// copies of one function means a future change to the speed list would be
/// applied in one place or two, not three.
double mtNextSpeed(double current) {
  final options = PlaybackSpeeds.options;
  final index = options.indexWhere((s) => (s - current).abs() < 0.01);
  return options[(index + 1) % options.length];
}
