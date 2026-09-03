import 'dart:async';

import 'package:audio_service/audio_service.dart';

import '../models/play_mode.dart';
import '../models/playback_source.dart';
import '../models/playlist_item.dart';
import '../stores/audio_state_store.dart';
import '../stores/playback_position_store.dart';
import '../stores/playback_prefs.dart';
import 'media_item_mapper.dart';
import 'media_player_port.dart';
import 'playback_queue.dart';
import 'playback_state_mapping.dart';

part 'audio_handler_recovery.dart';

/// مشغل الصوت الخلفي (م-21): إشعار وسائط وأزرار شاشة قفل، أوضاع تشغيل
/// وعشوائي، تخطي تلقائي للعنصر المعطوب، حفظ دوري للموضع، واستعادة
/// الجلسة بعد إعادة تشغيل التطبيق.
///
/// **القاعدة الذهبية (م-19):** المصدر من [PlaybackSourceResolver] — محلي
/// إن وُجد على القرص وإلا بث بترويسات المصادقة، والموضع مشترك بينهما.
///
/// **فخ §6.5:** [stop] ينظف `mediaItem` و`queue` والحالة المحفوظة معاً،
/// وإلا بقي «مشغل مصغر شبح» بعد الإيقاف.
class MTAudioHandler extends BaseAudioHandler with SeekHandler {
  MTAudioHandler({
    required this.player,
    required this.resolver,
    required this.positions,
    required this.prefs,
    required this.stateStore,
    Duration saveInterval = const Duration(seconds: 5),
  }) {
    _subs
      ..add(player.events.listen((_) => _broadcast()))
      ..add(player.stateStream.listen(_onState))
      ..add(player.errors.listen((_) => unawaited(_onError())));
    _saveTimer = Timer.periodic(saveInterval, (_) => unawaited(persist()));
  }

  final MediaPlayerPort player;
  final PlaybackSourceResolver resolver;
  final PlaybackPositionStore positions;
  final PlaybackPrefs prefs;
  final AudioStateStore stateStore;

  final List<StreamSubscription<Object?>> _subs = [];
  PlaybackQueue _queue = PlaybackQueue(items: const []);
  PlayMode _playMode = PlayMode.autoNext;
  String? _playlistId;
  int _consecutiveErrors = 0;
  Timer? _saveTimer;

  /// **حارس السباق (العطل ع-3).** جلسة الفيديو والريلز تحملان حارساً
  /// مماثلاً، وهذا المشغل كان بلا حارس رغم أنه أكثرها مداخل: نقرتان
  /// سريعتان على أغنيتين قد تُبقيان A يعزف بينما الإشعار يعرض B،
  /// و`persist()` يكتب موضع B تحت مفتاح A. والأخطر: سحب المشغل المصغر
  /// (stop) أثناء تحميل معلّق كان **يعيده حياً يعزف**.
  int _generation = 0;

  /// يُستدعى قبل أي بدء تشغيل صوتي: يوقف جلسة الفيديو الحية.
  ///
  /// **الاتجاه المعاكس للقاعدة الذهبية (العطل ع-4):** «مخرج واحد» كانت
  /// منفّذة باتجاه واحد فقط (فتح فيديو ⇒ يوقف الصوت). فكان زر التشغيل
  /// في إشعار الوسائط أثناء الفيديو — أو تشغيل صوتيات من شاشة القوائم
  /// المفتوحة فوق المشغل — يُسمع **مصدرين معاً**.
  Future<void> Function()? onTakeVideoFocus;

  PlayMode get playMode => _playMode;
  bool get shuffleEnabled => _queue.shuffle;
  PlaylistItem? get currentItem => _queue.current;

  /// **مفتاح ما يُعزف الآن كتيار** (canonicalUrl) — لمؤشر «يشغَّل الآن».
  ///
  /// [currentItem] لقطة لحظية: مراقبتها عبر `ref.watch` على مزوّد مثبّت
  /// بـ override **لا يتحدث أبداً**، فكان المؤشر يعلق على المقطع الأول
  /// مهما تقدمت القائمة (لقطة المالك 2026-09-02 — العطل ط-8). الواجهات
  /// تستهلك هذا التيار، ولا تحتاج معه معرفة `audio_service` أصلاً.
  Stream<String?> get currentKey =>
      mediaItem.map((item) => item?.id).distinct();

  /// العناصر بترتيب الإدراج (فهارسها هي التي يقبلها [skipToQueueItem]).
  List<PlaylistItem> get items => _queue.items;

  /// العناصر بترتيب التشغيل الفعلي — لعرض «التالي».
  List<PlaylistItem> get orderedItems => _queue.ordered;
  int get currentIndex => _queue.index;
  Stream<Duration> get positionStream => player.positionStream;

  /// يُستدعى مرة عند الإقلاع: التفضيلات المحفوظة (§5.1).
  Future<void> loadPreferences() async {
    _playMode = await prefs.playMode();
    await player.setSpeed(await prefs.speed());
  }

  /// تشغيل القائمة المعروضة وقت النقر (ر-4).
  Future<void> playItems(
    List<PlaylistItem> items, {
    int startIndex = 0,
    String? playlistId,
    bool autoPlay = true,
  }) async {
    if (items.isEmpty) return;
    // **الحارس يبدأ من هنا لا من `_loadCurrent`** (كشفه اختبار ع-3):
    // بين هذا السطر و`_loadCurrent` قراءتان من التفضيلات. إيقافٌ يقع
    // خلالهما (سحب المشغل المصغر) كان يكتمل ثم **يواصل هذا المسار
    // فيبني الطابور ويعزف** — فيعود الشريط الذي أغلقته حياً.
    final generation = ++_generation;
    _playlistId = playlistId;
    _playMode = await prefs.playMode(playlistId: playlistId);
    final shuffle = await prefs.shuffle();
    if (_isStale(generation)) return;
    _consecutiveErrors = 0;
    _queue = PlaybackQueue(
      items: items,
      index: startIndex,
      shuffle: shuffle,
    );
    _publishQueue();
    await _loadCurrent(autoPlay: autoPlay);
  }

  /// إحياء الجلسة المحفوظة بعد إعادة تشغيل التطبيق — **بلا تشغيل
  /// تلقائي**؛ يظهر المشغل المصغر ليكمل المستخدم بنقرة.
  Future<bool> restoreSession() async {
    final generation = ++_generation;
    final snapshot = await stateStore.read();
    if (snapshot == null || snapshot.isEmpty) return false;
    _playlistId = snapshot.playlistId;
    _playMode = await prefs.playMode(playlistId: _playlistId);
    final shuffle = await prefs.shuffle();
    // نقرة المستخدم على أغنية أثناء الاستعادة تفوز — لا تُداس بلقطة قديمة.
    if (_isStale(generation)) return false;
    _queue = PlaybackQueue(
      items: snapshot.items,
      index: snapshot.index,
      shuffle: shuffle,
    );
    _publishQueue();
    await _loadCurrent(autoPlay: false, startAt: snapshot.position);
    return true;
  }

  // ── الأوامر (الإشعار وشاشة القفل والواجهة) ──
  //
  // **تبقى في الصنف** ولا تُنقل لملف `part`: الامتداد لا يتجاوز دالة
  // الأصل، فكان `audio_service` سينادي نسخة `BaseAudioHandler` بدلاً
  // منها — خطأ صحّة اكتُشف في الفحص الشامل 2026-09-02.

  @override
  Future<void> play() async {
    await _takeVideoFocus();
    await player.play();
  }

  /// **إسكات الفيديو لا يُلغي التشغيل** (2026-09-03): المسجِّل شاشةٌ قد
  /// تموت، ورميةٌ منه كانت تُجهض `player.play()` قبل أن يبدأ — فيبدو
  /// التطبيق وكأنه «لا يشغّل شيئاً» بعد زيارة الريلز (بلاغ المالك).
  Future<void> _takeVideoFocus() async {
    try {
      await onTakeVideoFocus?.call();
    } on Object {
      onTakeVideoFocus = null; // مسجِّل ميت لا يُسأل مرة أخرى
    }
  }

  @override
  Future<void> pause() async {
    await player.pause();
    await persist();
  }

  @override
  Future<void> seek(Duration position) => player.seek(position);

  @override
  Future<void> skipToNext() => _skip(forward: true);

  @override
  Future<void> skipToPrevious() => _skip(forward: false);

  /// نقرة عنصر في ورقة قائمة الانتظار — [index] فهرس داخل العناصر.
  @override
  Future<void> skipToQueueItem(int index) async {
    await savePosition();
    if (!_queue.jumpTo(index)) return;
    await _loadCurrent(autoPlay: true);
  }

  @override
  Future<void> setSpeed(double speed) async {
    final value = PlaybackSpeeds.clamp(speed);
    await player.setSpeed(value);
    await prefs.setSpeed(value);
    _broadcast();
  }

  Future<void> setPlayMode(PlayMode mode) async {
    _playMode = mode;
    await prefs.setPlayMode(mode, playlistId: _playlistId);
    _broadcast();
  }

  Future<void> setShuffle(bool value) async {
    _queue.setShuffle(value);
    await prefs.setShuffle(value);
    _publishQueue();
    _broadcast();
  }

  /// **فخ §6.5** — الإيقاف ينظف كل ما يُظهر المشغل المصغر.
  @override
  Future<void> stop() async {
    _generation++; // تحميل معلّق لا يعيد إحياء المشغل المصغر بعد الإغلاق
    await savePosition();
    await player.stop();
    _queue = PlaybackQueue(items: const []);
    _playlistId = null;
    mediaItem.add(null);
    queue.add(const []);
    await stateStore.clear();
    playbackState.add(PlaybackState(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    await super.stop();
  }

  Future<void> dispose() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await player.dispose();
  }

  // ── الداخلية ──

  Future<void> _skip({required bool forward}) async {
    await savePosition();
    final moved = forward
        ? _queue.moveNext(_playMode, userInitiated: true)
        : _queue.movePrevious(_playMode);
    if (!moved) return;
    await _loadCurrent(autoPlay: true);
  }

  void _onState(MediaPlaybackState state) {
    if (state == MediaPlaybackState.completed) unawaited(onCompleted());
  }

  /// انتهى المقطع طبيعياً ⇒ الوضع يقرر (م-20).
  Future<void> onCompleted() async {
    final url = _queue.current?.canonicalUrl;
    if (url != null) await positions.clear(url);
    if (_playMode == PlayMode.repeatOne) {
      await player.seek(Duration.zero);
      return player.play();
    }
    if (_playMode != PlayMode.stopAtEnd && _queue.moveNext(_playMode)) {
      return _loadCurrent(autoPlay: true);
    }
    await player.pause();
    await player.seek(Duration.zero);
    _broadcast();
  }

  void _broadcast() {
    final playing = player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: mtMediaControls(playing: playing),
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: mtProcessingState(player.state),
      playing: playing,
      updatePosition: player.position,
      bufferedPosition: player.bufferedPosition,
      speed: player.speed,
      queueIndex: _queue.index < 0 ? null : _queue.index,
      repeatMode: mtRepeatMode(_playMode),
      shuffleMode: mtShuffleMode(shuffle: _queue.shuffle),
    ));
  }
}
