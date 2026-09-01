import 'package:mt_core/mt_core.dart';

/// مواضع الاستئناف — المفتاح `playback_pos_<canonicalUrl>` (§5.1).
/// نفس المفتاح للبث والنسخة المحلية ⇒ الاستئناف مشترك بينهما (م-19).
class PlaybackPositionStore {
  PlaybackPositionStore({required this.store, required this.mutex});

  final KeyValueStore store;
  final PrefsMutex mutex;

  static const String prefix = 'playback_pos_';

  /// أقل من هذا لا يستحق الحفظ (مشاهدة عابرة تُفسد «تابع من حيث وقفت»).
  static const Duration minimumToSave = Duration(seconds: 5);

  /// قرب النهاية = انتهى العنصر ⇒ يُمسح ليبدأ من أوله في المرة القادمة.
  static const Duration endThreshold = Duration(seconds: 10);

  String keyOf(String canonicalUrl) => '$prefix$canonicalUrl';

  Future<Duration?> positionOf(String canonicalUrl) async {
    final ms = await store.getInt(keyOf(canonicalUrl));
    if (ms == null || ms <= 0) return null;
    return Duration(milliseconds: ms);
  }

  /// يحفظ الموضع بقواعده الثلاث: يتجاهل البدايات، ويمسح عند الاقتراب من
  /// النهاية، ويكتب ما عدا ذلك. [duration] المجهولة تعطّل قاعدة النهاية.
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

  /// تنظيف كل المواضع (يُستدعى من «مسح البيانات» ومن استعادة نسخة).
  Future<void> clearAll() => mutex.run(() async {
        final keys = await store.keys();
        for (final key in keys.where((k) => k.startsWith(prefix))) {
          await store.remove(key);
        }
      });
}
