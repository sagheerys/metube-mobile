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
      MediaControl.stop,
    ];

AudioProcessingState mtProcessingState(MediaPlaybackState state) =>
    switch (state) {
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

AudioServiceShuffleMode mtShuffleMode({required bool shuffle}) => shuffle
    ? AudioServiceShuffleMode.all
    : AudioServiceShuffleMode.none;
