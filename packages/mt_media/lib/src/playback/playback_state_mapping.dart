import 'package:audio_service/audio_service.dart';

import '../models/play_mode.dart';
import 'media_player_port.dart';

/// Translates the internal player state into `audio_service` vocabulary.
/// Pure functions split out of `MTAudioHandler` for the size limit (rule
/// 4), and also the only unit here testable without a real player.

/// The notification and lock-screen buttons. The order is the display
/// order, and `androidCompactActionIndices` points at the first three.
List<MediaControl> mtMediaControls({required bool playing}) => [
  MediaControl.skipToPrevious,
  if (playing) MediaControl.pause else MediaControl.play,
  MediaControl.skipToNext,
  mtCloseControl,
];

/// **Stop, drawn as a close mark** (design review 2026-09-25): the square
/// stop icon looked out of place among music players, while the button
/// itself is needed, because a paused session keeps its notification. Same
/// action, another icon; the drawable ships in each app's resources.
const MediaControl mtCloseControl = MediaControl(
  androidIcon: 'drawable/$mtCloseIcon',
  label: 'Close',
  action: MediaAction.stop,
);

/// The resource name both apps must ship under `res/drawable`.
const String mtCloseIcon = 'ic_mt_close';

/// **Idle is published only when the session really ends.** audio_service
/// treats any move into idle as the end and stops its service, removing the
/// notification and the foreground with it. just_audio reports idle for a
/// moment each time it loads a new source, still playing, so a skip or a
/// song ending would end the session mid-playlist and leave the sound
/// running unprotected. While [sessionOpen] (a queue is loaded) that moment
/// reads as loading, which it is.
AudioProcessingState mtProcessingState(
  MediaPlaybackState state, {
  required bool sessionOpen,
}) => switch (state) {
  MediaPlaybackState.idle when sessionOpen => AudioProcessingState.loading,
  MediaPlaybackState.idle => AudioProcessingState.idle,
  MediaPlaybackState.loading => AudioProcessingState.loading,
  MediaPlaybackState.buffering => AudioProcessingState.buffering,
  MediaPlaybackState.ready => AudioProcessingState.ready,
  MediaPlaybackState.completed => AudioProcessingState.completed,
};

AudioServiceRepeatMode mtRepeatMode(PlayMode mode) => switch (mode) {
  PlayMode.repeatOne => AudioServiceRepeatMode.one,
  PlayMode.repeatAll => AudioServiceRepeatMode.all,
  _ => AudioServiceRepeatMode.none,
};

AudioServiceShuffleMode mtShuffleMode({required bool shuffle}) =>
    shuffle ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none;
