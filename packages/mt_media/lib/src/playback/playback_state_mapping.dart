import 'package:audio_service/audio_service.dart';

import '../models/play_mode.dart';
import 'media_player_port.dart';

/// ترجمة حالة المشغل الداخلية إلى مفردات `audio_service` — دوال خالصة
/// فُصلت عن `MTAudioHandler` لحدّ الأسطر (القاعدة 4)، وهي أيضاً الوحدة
/// الوحيدة القابلة للاختبار بلا مشغل حقيقي.

/// أزرار الإشعار وشاشة القفل. الترتيب هو ترتيب العرض،
/// و`androidCompactActionIndices` يشير إلى أول ثلاثة منها.
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
