import 'package:mt_core/mt_core.dart';

import '../models/play_mode.dart';

/// تفضيلات المشغلات المحفوظة (§5.1): وضع التشغيل، السرعة، العشوائي.
/// وضع التشغيل يقبل مفتاحاً فرعياً لكل قائمة (`player_play_mode_<id>`)
/// كما في المخطط، والافتراض العام حين لا يوجد مخصص.
class PlaybackPrefs {
  PlaybackPrefs({required this.store, required this.mutex});

  final KeyValueStore store;
  final PrefsMutex mutex;

  static const String playModeKey = 'player_play_mode';
  static const String speedKey = 'player_playback_speed';
  static const String shuffleKey = 'audio_shuffle';

  String _modeKey(String? playlistId) =>
      playlistId == null || playlistId.isEmpty
          ? playModeKey
          : '${playModeKey}_$playlistId';

  Future<PlayMode> playMode({String? playlistId}) async {
    final specific = playlistId == null
        ? null
        : await store.getString(_modeKey(playlistId));
    return PlayMode.fromWire(specific ?? await store.getString(playModeKey));
  }

  Future<void> setPlayMode(PlayMode mode, {String? playlistId}) =>
      mutex.run(() => store.setString(_modeKey(playlistId), mode.wire));

  Future<double> speed() async =>
      PlaybackSpeeds.clamp(await store.getDouble(speedKey) ??
          PlaybackSpeeds.normal);

  Future<void> setSpeed(double value) => mutex.run(
        () => store.setDouble(speedKey, PlaybackSpeeds.clamp(value)),
      );

  Future<bool> shuffle() async => await store.getBool(shuffleKey) ?? false;

  Future<void> setShuffle(bool value) =>
      mutex.run(() => store.setBool(shuffleKey, value));
}
