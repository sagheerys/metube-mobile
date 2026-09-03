import '../models/playback_source.dart';

/// حالة المشغل كما يراها منطقنا — مستقلة عن حزمة التشغيل.
enum MediaPlaybackState { idle, loading, buffering, ready, completed }

/// المنفذ الذي يكلّم به [MTAudioHandler] أي مشغل فعلي.
///
/// وجوده متعمَّد: منطق القائمة والأوضاع وحفظ الموضع و«لا مشغل شبح»
/// يُختبر كاملاً بلا قنوات منصة (TRD §3.2)، وحزمة التشغيل تبقى تفصيلاً
/// قابلاً للاستبدال في مكان واحد.
abstract interface class MediaPlayerPort {
  Future<void> setSource(PlaybackSource source, {Duration initialPosition});

  /// **عقدها «أصدر أمر التشغيل» لا «شغّل حتى النهاية»** — يكتمل
  /// مستقبلها حين يُقبل الأمر. حزمة `just_audio` تفعل العكس (مستقبلها
  /// يكتمل عند التوقف)، فتغليفها هو ما يحفظ هذا العقد. كسرُه علّق شاشة
  /// الفيديو وأسقط الغلاف لاحقاً (بلاغ المالك 2026-09-03).
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
  Future<void> seek(Duration position);
  Future<void> setSpeed(double speed);

  Duration get position;
  Duration get bufferedPosition;
  Duration? get duration;
  double get speed;
  bool get playing;
  MediaPlaybackState get state;

  /// أي تغيّر يستوجب إعادة بث حالة الإشعار.
  Stream<void> get events;
  Stream<MediaPlaybackState> get stateStream;
  Stream<Duration> get positionStream;

  /// أخطاء التشغيل (مصدر معطوب، شبكة منقطعة) ⇒ تخطي تلقائي (م-21).
  Stream<Object> get errors;

  Future<void> dispose();
}
