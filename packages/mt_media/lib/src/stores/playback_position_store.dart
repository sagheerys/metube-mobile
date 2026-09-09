import 'package:mt_core/mt_core.dart';

/// Resume positions, keyed `playback_pos_<canonicalUrl>` (§5.1). The same
/// key for the stream and the local copy, so resuming is shared between
/// them.
class PlaybackPositionStore {
  PlaybackPositionStore({required this.store, required this.mutex});

  final KeyValueStore store;
  final PrefsMutex mutex;

  static const String prefix = 'playback_pos_';

  /// Anything shorter is not worth saving; a glance would spoil "continue
  /// where you left off".
  static const Duration minimumToSave = Duration(seconds: 5);

  /// Near the end means the item finished, so it is cleared and starts from
  /// the beginning next time.
  static const Duration endThreshold = Duration(seconds: 10);

  String keyOf(String canonicalUrl) => '$prefix$canonicalUrl';

  Future<Duration?> positionOf(String canonicalUrl) async {
    final ms = await store.getInt(keyOf(canonicalUrl));
    if (ms == null || ms <= 0) return null;
    return Duration(milliseconds: ms);
  }

  /// Saves the position under its three rules: ignore the opening, clear
  /// near the end, and write anything else. An unknown [duration] disables
  /// the end rule.
  Future<void> save(
    String canonicalUrl,
    Duration position, {
    Duration? duration,
  }) async {
    if (canonicalUrl.isEmpty) return;
    if (position < minimumToSave) return clear(canonicalUrl);
    if (duration != null &&
        duration > Duration.zero &&
        position >= duration - endThreshold) {
      return clear(canonicalUrl);
    }
    await mutex.run(
      () => store.setInt(keyOf(canonicalUrl), position.inMilliseconds),
    );
  }

  Future<void> clear(String canonicalUrl) =>
      mutex.run(() => store.remove(keyOf(canonicalUrl)));

  /// Clears every position, called from "clear data" and from restoring a
  /// backup.
  Future<void> clearAll() => mutex.run(() async {
    final keys = await store.keys();
    for (final key in keys.where((k) => k.startsWith(prefix))) {
      await store.remove(key);
    }
  });
}
