import 'dart:async';

import 'package:just_audio/just_audio.dart';

import '../models/playback_source.dart';
import 'media_player_port.dart';

/// تنفيذ [MediaPlayerPort] فوق `just_audio` — **المكان الوحيد** الذي
/// يعرف الحزمة، فيبقى منطق المشغل قابلاً للاختبار بلا منصة.
class JustAudioPort implements MediaPlayerPort {
  JustAudioPort({AudioPlayer? player}) : _player = player ?? AudioPlayer() {
    _errors = StreamController<Object>.broadcast();
    _eventSub = _player.playbackEventStream.listen(
      (_) => _events.add(null),
      onError: (Object error, StackTrace _) => _errors.add(error),
    );
  }

  final AudioPlayer _player;
  final StreamController<void> _events = StreamController<void>.broadcast();
  late final StreamController<Object> _errors;
  StreamSubscription<PlaybackEvent>? _eventSub;

  @override
  Future<void> setSource(
    PlaybackSource source, {
    Duration initialPosition = Duration.zero,
  }) =>
      _player.setAudioSource(
        AudioSource.uri(source.uri, headers: source.headers),
        initialPosition: initialPosition,
      );

  /// **مستقبل `play()` في just_audio لا يكتمل إلا حين يتوقف التشغيل** —
  /// نصّ الحزمة: «يكتمل حين ينتهي التشغيل أو يُوقَف». فانتظاره يعني
  /// انتظار المقطع كله (بلاغ المالك 2026-09-03):
  ///
  /// «متابعة صوتاً» كانت تعلّق شاشة الفيديو فلا تُغلق مهما انتظرت،
  /// **ثم** يُنفَّذ `pop` المؤجل عند إيقاف الصوت — وقد غادر المستخدم
  /// الشاشة بطريق آخر — فيُسقط الغلاف نفسه: **شاشة سوداء**.
  ///
  /// عقد [MediaPlayerPort.play] هو «أصدر أمر التشغيل»، لا «شغّل حتى
  /// النهاية». الخطأ يُحوَّل إلى مجرى الأخطاء فيتخطّى المعالجُ العنصر.
  @override
  Future<void> play() async {
    unawaited(_player.play().catchError((Object error) {
      if (!_errors.isClosed) _errors.add(error);
    }));
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);

  @override
  Duration get position => _player.position;

  @override
  Duration get bufferedPosition => _player.bufferedPosition;

  @override
  Duration? get duration => _player.duration;

  @override
  double get speed => _player.speed;

  @override
  bool get playing => _player.playing;

  @override
  MediaPlaybackState get state => _map(_player.processingState);

  @override
  Stream<void> get events => _events.stream;

  @override
  Stream<MediaPlaybackState> get stateStream =>
      _player.processingStateStream.map(_map);

  @override
  Stream<Duration> get positionStream => _player.positionStream;

  @override
  Stream<Object> get errors => _errors.stream;

  @override
  Future<void> dispose() async {
    await _eventSub?.cancel();
    await _events.close();
    await _errors.close();
    await _player.dispose();
  }

  static MediaPlaybackState _map(ProcessingState state) => switch (state) {
        ProcessingState.idle => MediaPlaybackState.idle,
        ProcessingState.loading => MediaPlaybackState.loading,
        ProcessingState.buffering => MediaPlaybackState.buffering,
        ProcessingState.ready => MediaPlaybackState.ready,
        ProcessingState.completed => MediaPlaybackState.completed,
      };
}
