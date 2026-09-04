import '../models/download_task.dart';
import '../models/saved_playlist.dart';
import 'playlists_store.dart';

/// **تجميع تحميل قائمة في قائمة محفوظة واحدة** (سؤال المالك 2026-09-02:
/// «عند تحميل دورة من يوتيوب هل تُجمع مع بعضها؟»).
///
/// كان الجواب **لا**: `isBatchMember` لم يكن يفعل شيئاً سوى ترتيب
/// الطابور (المفرد يسبق أعضاء الدفعة)، والعناصر تتناثر في المكتبة بلا
/// رابط بينها — وكذلك كان المشروع القديم في `Z:\MTD`.
///
/// الآن: شاشة الدفعي تفتح قائمة باسم قائمة المصدر، وكل عنصر يكتمل
/// يُضاف إليها **بترتيب المصدر لا ترتيب الاكتمال** (التحميل متزامن
/// واحد لكن الفشل يزيح الترتيب). القائمة الفارغة تماماً (فشل الكل)
/// تُحذف فلا تبقى قائمة شبح.
class BatchPlaylistCollector {
  BatchPlaylistCollector({required this.playlists, this.onChanged});

  final PlaylistsStore playlists;

  /// **يُخبِر الواجهة أن القوائم تغيّرت** (بلاغ ميداني 2026-09-03).
  /// القائمة المُجمَّعة كانت تُكتب على القرص صحيحةً **ولا تظهر أبداً**:
  /// الكتابة تقع خارج شاشة القوائم، وغلاف `indexedStack` يُبقي تبويبها
  /// حياً بمزوّدٍ يحتفظ بقيمته المخبأة — فلا يُقرأ القرص ثانيةً حتى
  /// إعادة تشغيل التطبيق.
  final void Function()? onChanged;

  /// taskId ⇒ (معرف القائمة، ترتيب العنصر في المصدر).
  final Map<String, (String playlistId, int order)> _members = {};

  /// عدد ما لم ينتهِ بعد لكل قائمة — لتنظيف القائمة الفارغة عند النهاية.
  final Map<String, int> _remaining = {};

  /// ما أُضيف فعلاً لكل قائمة — لمعرفة الفارغة.
  final Map<String, int> _added = {};

  /// أول موضع لأعضاء هذه الدفعة داخل القائمة — 0 للقائمة الجديدة،
  /// وطولُ الموجود عند إعادة استعمال قائمة قائمة.
  final Map<String, int> _base = {};

  /// يُنشئ القائمة — **أو يعيد استعمال القائمة ذات الاسم نفسه** —
  /// ويسجّل مهامها. [taskIds] بترتيب المصدر.
  ///
  /// بلاغ المالك 2026-09-04: «حمّلت القائمة من يوتيوب مرة أخرى فظهرت
  /// في قائمة جديدة وصار عندي قائمتان». `create` كانت تُنشئ قائمة في
  /// كل مرة بلا سؤال. الآن: نفس الاسم ⇒ نفس القائمة، والمداخل المكررة
  /// يمنعها [PlaylistsStore.addItems] بالرابط المُقنون — فإعادة تحميل
  /// المصدر تُحيي المداخل الميتة بدل أن تستنسخ القائمة.
  Future<SavedPlaylist> begin(String name, List<String> taskIds) async {
    final existing = await playlists.byName(name);
    final playlist = existing ?? await playlists.create(name);
    // الترتيب المطلوب يُزاح بما في القائمة أصلاً، وإلا قفز عضو الدفعة
    // الأول إلى رأس قائمة فيها عشرة عناصر.
    _base[playlist.id] = existing?.items.length ?? 0;
    for (var i = 0; i < taskIds.length; i++) {
      _members[taskIds[i]] = (playlist.id, i);
    }
    _remaining[playlist.id] = taskIds.length;
    _added[playlist.id] = 0;
    onChanged?.call();
    return playlist;
  }

  /// يُنادى عند اكتمال مهمة (من `onCompleted` في المحرك).
  Future<void> onFinished(DownloadTask task) async {
    final member = _members.remove(task.id);
    if (member == null) return;
    final (playlistId, order) = member;
    final url = task.canonicalUrl;
    if (url != null && url.isNotEmpty) {
      await playlists.addItems(playlistId, [
        PlaylistEntry(
          canonicalUrl: url,
          serverFilename: task.serverFilename,
          cachedTitle: task.title,
          cachedThumb: task.thumbnail,
        ),
      ]);
      await _placeAt(playlistId, url, order);
      _added[playlistId] = (_added[playlistId] ?? 0) + 1;
    }
    await _closeIfDone(playlistId);
    onChanged?.call();
  }

  /// يُنادى عند فشل/إلغاء عضو دفعة — لا يُضاف شيء لكن العدّ يتقدم.
  Future<void> onDropped(String taskId) async {
    final member = _members.remove(taskId);
    if (member == null) return;
    await _closeIfDone(member.$1);
    onChanged?.call();
  }

  /// إعادة العنصر لموضعه من المصدر (الإضافة تأتي بترتيب الاكتمال).
  Future<void> _placeAt(String playlistId, String url, int order) async {
    final playlist = await playlists.byId(playlistId);
    if (playlist == null) return;
    final current = playlist.items.indexWhere((e) => e.canonicalUrl == url);
    if (current < 0) return;
    final target =
        (order + (_base[playlistId] ?? 0)).clamp(0, playlist.items.length - 1);
    if (current != target) {
      await playlists.reorderItem(playlistId, current, target);
    }
  }

  Future<void> _closeIfDone(String playlistId) async {
    final left = (_remaining[playlistId] ?? 1) - 1;
    _remaining[playlistId] = left;
    if (left > 0) return;
    _remaining.remove(playlistId);
    final base = _base.remove(playlistId) ?? 0;
    final added = _added.remove(playlistId) ?? 0;
    // **لا تُحذف قائمة كانت موجودة قبلنا**: الحذف علاجٌ لقائمةٍ أنشأناها
    // نحن ثم سقط كل أعضائها — لا لقائمة المستخدم التي أضفنا إليها.
    if (added == 0 && base == 0) await playlists.delete(playlistId);
  }
}
