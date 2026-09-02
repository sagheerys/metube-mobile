import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../models/play_mode.dart';
import '../models/playback_source.dart';
import '../models/playlist_item.dart';
import '../playback/playback_queue.dart';
import '../stores/playback_position_store.dart';
import '../stores/playback_prefs.dart';

part 'mt_video_session_commands.dart';

/// جلسة مشغل الفيديو (م-20): تملك المتحكم والطابور والأوضاع، وتطبق
/// **القاعدة الذهبية** (م-19) في اختيار المصدر مثل مشغل الصوت تماماً،
/// وتتشارك معه مفتاح الموضع فيستأنف كلٌّ من حيث وقف الآخر (م-23).
class MTVideoSession extends ChangeNotifier {
  MTVideoSession({
    required this.resolver,
    required this.positions,
    required this.prefs,
    Duration saveInterval = const Duration(seconds: 5),
  }) {
    _saveTimer = Timer.periodic(saveInterval, (_) => unawaited(savePosition()));
  }

  final PlaybackSourceResolver resolver;
  final PlaybackPositionStore positions;
  final PlaybackPrefs prefs;

  PlaybackQueue _queue = PlaybackQueue(items: const []);
  VideoPlayerController? _controller;
  PlayMode _playMode = PlayMode.autoNext;
  String? _playlistId;
  String? _error;
  bool _loading = false;
  bool _disposed = false;
  bool _wakelockOn = false;
  int _consecutiveErrors = 0;
  Timer? _saveTimer;

  /// **مزلاج الاكتمال (العطل ط-2/4):** شرط النهاية يظل صحيحاً في كل
  /// إشعار لاحق من المتحكم، فكان `onCompleted` يُستدعى مرتين: تخطي
  /// عنصرين دفعة، **ومسح موضع استئناف عنصر لم يُشاهد قط**.
  String? _completedUrl;

  /// **حارس السباق (خلل مصطاد على جهاز المالك 2026-09-01).** `_load`
  /// ينتظر `initialize()` — ثوانٍ على شبكة بطيئة. تخطٍّ ثانٍ أثناء
  /// الانتظار يبدأ تحميلاً موازياً، ويفوز آخر من ينتهي بـ `_controller`
  /// بينما **يبقى الأول حياً يشتغل صوتاً بلا صورة**: مقطعان معاً.
  int _generation = 0;

  /// يُستدعى قبل أي بدء تشغيل: يوقف مشغل الصوت الخلفي فلا يشتغل
  /// المصدران معاً (م-19 — مخرج صوت واحد في كل لحظة).
  Future<void> Function()? onTakeAudioFocus;

  VideoPlayerController? get controller => _controller;
  PlaylistItem? get current => _queue.current;
  List<PlaylistItem> get items => _queue.items;
  List<PlaylistItem> get orderedItems => _queue.ordered;
  int get currentIndex => _queue.index;
  PlayMode get playMode => _playMode;
  bool get shuffleEnabled => _queue.shuffle;
  String? get playlistId => _playlistId;
  String? get error => _error;
  bool get isLoading => _loading;
  bool get isPlaying => _controller?.value.isPlaying ?? false;
  Duration get position => _controller?.value.position ?? Duration.zero;
  Duration? get duration => _controller?.value.duration;

  /// فتح قائمة في المشغل — القائمة المعروضة وقت النقر (ر-4 خطوة 1).
  Future<void> open(
    List<PlaylistItem> items, {
    int startIndex = 0,
    String? playlistId,
  }) async {
    if (items.isEmpty) return;
    _playlistId = playlistId;
    _playMode = await prefs.playMode(playlistId: playlistId);
    _consecutiveErrors = 0;
    _queue = PlaybackQueue(
      items: items,
      index: startIndex,
      shuffle: await prefs.shuffle(),
    );
    await _load();
  }

  /// `notifyListeners` محمية ولا تُنادى من امتداد ولو في نفس المكتبة —
  /// هذه نافذتها الوحيدة لملف الأوامر (`part`).
  void notifyFromCommands() => notifyListeners();

  Future<void> _load() async {
    final item = _queue.current;
    if (item == null) return;
    final generation = ++_generation;
    _loading = true;
    _error = null;
    notifyListeners();

    await _disposePlayers();
    final source = resolver.resolve(item);
    if (source == null) return _failCurrent();

    final controller = source.isLocal
        ? VideoPlayerController.file(File(source.uri.toFilePath()))
        : VideoPlayerController.networkUrl(source.uri,
            httpHeaders: source.headers);
    try {
      await controller.initialize();
    } on Object {
      await controller.dispose();
      // تحميل أحدث سبقنا ⇒ هذا الفشل لم يعد يخصّ الشاشة.
      if (generation != _generation) return;
      return _failCurrent();
    }
    if (_disposed || generation != _generation) return controller.dispose();

    // **النشر بعد اكتمال التهيئة لا قبلها (العطل ط-2/1).** كان
    // `_controller` يُنشر ثم تأتي ثلاث `await` (موضع، seek، سرعة) بلا
    // حارس بينها: تخطٍّ ثانٍ سريع يصرّف هذا المتحكم نفسه أثناءها فترمي
    // `seekTo` بـ«controller was used after being disposed».
    _consecutiveErrors = 0;
    _completedUrl = null;
    final resume = await positions.positionOf(item.canonicalUrl);
    if (_disposed || generation != _generation) return controller.dispose();
    if (resume != null && resume < (controller.value.duration)) {
      await controller.seekTo(resume);
    }
    await controller.setPlaybackSpeed(await prefs.speed());
    if (_disposed || generation != _generation) return controller.dispose();

    _controller = controller;
    controller.addListener(_onTick);
    await onTakeAudioFocus?.call();
    if (_disposed || generation != _generation) return;
    await controller.play();
    _loading = false;
    notifyListeners();
    _rememberShape(item, controller);
  }

  /// المدة والنسبة تُعرفان بعد التحضير — تُحفظان في العنصر لمسار
  /// القِصار (م-35) في الجلسة الحالية.
  void _rememberShape(PlaylistItem item, VideoPlayerController controller) {
    final index = _queue.items.indexOf(item);
    if (index < 0) return;
    final value = controller.value;
    onShapeKnown?.call(
      item.canonicalUrl,
      value.duration,
      value.aspectRatio,
    );
  }

  /// يُبلَّغ الأعلى بأبعاد المقطع الحقيقية ليخزنها (م-35).
  void Function(String canonicalUrl, Duration duration, double aspectRatio)?
      onShapeKnown;

  Future<void> _failCurrent() async {
    _consecutiveErrors++;
    _loading = false;
    if (_queue.isEmpty || _consecutiveErrors >= _queue.length) {
      _error = 'source';
      notifyListeners();
      return;
    }
    if (_queue.moveNext(PlayMode.repeatAll)) {
      await _load();
    } else {
      _error = 'source';
      notifyListeners();
    }
  }

  void _onTick() {
    final value = _controller?.value;
    if (value == null) return;
    if (value.hasError) {
      unawaited(_failCurrent());
      return;
    }
    unawaited(_setWakelock(value.isPlaying));
    final url = _queue.current?.canonicalUrl;
    if (value.duration > Duration.zero &&
        value.position >= value.duration &&
        !value.isPlaying &&
        url != null &&
        _completedUrl != url) {
      _completedUrl = url;
      unawaited(onCompleted());
    }
    notifyListeners();
  }

  // ── الأوامر ──

  Future<void> playPause() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
      await savePosition();
    } else {
      await onTakeAudioFocus?.call();
      await controller.play();
    }
    notifyListeners();
  }

  /// إيقاف مؤقت صريح من الأعلى — م-23 «متابعة صوتاً» كان يشغّل الصوت
  /// **والفيديو ما زال يعمل**، فيُسمع المقطع مرتين حتى يُغلق المشغل
  /// (وعلى شبكة بطيئة يدوم التداخل ثوانيَ طويلة).
  Future<void> pause() async {
    final controller = _controller;
    if (controller == null || !controller.value.isPlaying) return;
    await controller.pause();
    await savePosition();
    notifyListeners();
  }

  Future<void> onCompleted() async {
    final url = _queue.current?.canonicalUrl;
    if (url != null) await positions.clear(url);
    if (_playMode == PlayMode.repeatOne) {
      await _controller?.seekTo(Duration.zero);
      return _controller?.play();
    }
    if (_playMode != PlayMode.stopAtEnd && _queue.moveNext(_playMode)) {
      return _load();
    }
    await _controller?.pause();
    notifyListeners();
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    _generation++; // يبطل أي تحميل معلّق فلا ينشر متحكماً بعد الموت
    _saveTimer?.cancel();
    _saveTimer = null;
    // **الإسكات قبل الحفظ (ط-2/2):** بين إغلاق الشاشة واكتمال الحفظ كان
    // الفيديو يبقى **مسموعاً فوق المكتبة**؛ وفشل الحفظ كان يمنع التصريف
    // نهائياً فيبقى المتحكم حياً.
    try {
      await _controller?.pause();
    } on Object {
      // لا شيء — التصريف تالياً على أي حال.
    }
    try {
      await savePosition();
    } on Object {
      // الحفظ ليس سبباً لترك متحكم حي خلفنا.
    }
    await _disposePlayers();
    super.dispose();
  }
}
