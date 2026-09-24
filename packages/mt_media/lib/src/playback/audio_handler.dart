import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;

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

/// The background audio player: a media notification and lock-screen
/// controls, play and shuffle modes, automatic skipping of a broken item,
/// periodic position saving, and session restoration after the app
/// restarts.
///
/// **The golden rule:** the source comes from [PlaybackSourceResolver],
/// local if it exists on disk and otherwise a stream with authentication
/// headers, and the position is shared between the two.
///
/// **Trap §6.5:** [stop] clears `mediaItem`, `queue` and the saved state
/// together, or a ghost mini player survives the stop.
class MTAudioHandler extends BaseAudioHandler with SeekHandler {
  MTAudioHandler({
    required this.player,
    required this.resolver,
    required this.positions,
    required this.prefs,
    required this.stateStore,
    Duration saveInterval = const Duration(seconds: 5),
    this.pausedAutoStop = const Duration(minutes: 15),
    this.networkRetryBackoff = const [
      Duration(seconds: 2),
      Duration(seconds: 5),
      Duration(seconds: 10),
    ],
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

  /// **How long a paused session may hold the foreground service** before
  /// it stops itself, releasing the wake lock and clearing the
  /// notification.
  ///
  /// It exists because of the other half of the 2026-09-19 fix: the service
  /// now survives a pause (`androidStopForegroundOnPause: false`), which is
  /// what lets playback come back after a phone call — and the price is a
  /// wake lock held for as long as the session is paused. Whoever pauses
  /// and walks away gets it back.
  final Duration pausedAutoStop;

  /// **The waits before retrying a stream that failed**, longest last. Its
  /// length is the number of retries, and `const []` disables them (tests).
  ///
  /// A dropped network used to be indistinguishable from a broken file:
  /// both reached `_onError`, which skipped to the next item, and five
  /// skips stopped the session. So one network hiccup silently ended a
  /// playlist. Only a **stream** is retried; a local file that fails to
  /// open is broken and skipping it is right.
  final List<Duration> networkRetryBackoff;

  final List<StreamSubscription<Object?>> _subs = [];
  PlaybackQueue _queue = PlaybackQueue(items: const []);
  PlayMode _playMode = PlayMode.autoNext;
  String? _playlistId;
  int _consecutiveErrors = 0;

  /// **How much of an item must play before its retry budget is returned.**
  ///
  /// Shorter than any clip worth watching and longer than the gap a
  /// flapping stream manages, so a genuine hiccup an hour into a podcast
  /// gets its retries back while a source that drops every few seconds
  /// runs out of them.
  static const Duration retryBudgetProgress = Duration(seconds: 30);

  /// **Only something this long picks up where it was left** (field report
  /// 2026-09-25: skipping through a music playlist, every song came back
  /// half-way in).
  ///
  /// Music players start a song from the top; podcast players resume an
  /// episode. Length is what tells the two apart without asking: songs are
  /// minutes, lectures and episodes are tens of minutes. Positions are
  /// still **saved** for everything, so the video player keeps resuming
  /// any clip, and reopening the app still continues the song that was
  /// playing — that is a session coming back, not a song being chosen.
  static const Duration resumeMinimumLength = Duration(minutes: 10);

  /// **"Previous" restarts the song first** (field report 2026-09-25, in
  /// the car): past this point one press goes back to the start, and a
  /// second press within it goes to the song before — what Samsung Music,
  /// Spotify and every car head unit expect.
  static const Duration restartThreshold = Duration(seconds: 3);

  /// Retries spent on the **current** item, and where it had reached when
  /// it last failed. Together they answer "is this the same fault over and
  /// over?" — see `_openRetryBudget`.
  int _networkRetries = 0;
  String? _retryKey;
  Duration? _lastRetryPosition;
  Timer? _saveTimer;
  Timer? _pausedStopTimer;

  /// Has this session played at all? The paused auto-stop is for a session
  /// that **was** playing and was left; a restored session that nobody has
  /// tapped yet holds no wake lock and must stay until they do.
  bool _wasPlaying = false;

  /// **The race guard.** The video and reels sessions carry a
  /// similar guard, and this player had none despite having the most entry
  /// points: two quick taps on two songs could leave A playing while the
  /// notification showed B, with `persist()` writing B's position under A's
  /// key. Worse, dismissing the mini player (stop) during a pending load
  /// **brought it back alive and playing**.
  int _generation = 0;

  /// Called before any audio playback starts: it stops the live video
  /// session.
  ///
  /// **The opposite direction of the golden rule:** "one
  /// output" was implemented one way only, so opening a video stopped
  /// audio. The play button in the media notification during a video, or
  /// starting audio from the playlists screen opened over the player,
  /// produced **two sources at once**.
  Future<void> Function()? onTakeVideoFocus;

  PlayMode get playMode => _playMode;
  bool get shuffleEnabled => _queue.shuffle;
  PlaylistItem? get currentItem => _queue.current;

  /// **What is playing now, as a stream** of canonicalUrl, for the "now
  /// playing" indicator.
  ///
  /// [currentItem] is a point-in-time snapshot: watching it through
  /// `ref.watch` on a provider pinned by an override **never updates**, so
  /// the indicator stuck on the first clip however far the queue advanced
  /// (screenshot 2026-09-02). Interfaces consume this stream
  /// and then need no knowledge of `audio_service` at all.
  Stream<String?> get currentKey =>
      mediaItem.map((item) => item?.id).distinct();

  /// **Is it actually playing right now?** Different from "which item is
  /// current" ([currentKey]). The "now playing" indicator used to dance
  /// over a paused clip because the interface knew only the current item
  /// (field report 2026-09-04).
  Stream<bool> get playingStream =>
      playbackState.map((state) => state.playing).distinct();

  /// The same information as a [Listenable], for sheets built once that do
  /// not watch a stream, such as the queue sheet, so their equaliser stops
  /// too.
  final ValueNotifier<bool> playingNotifier = ValueNotifier(false);

  /// The items in insertion order; those indexes are what [skipToQueueItem]
  /// accepts.
  List<PlaylistItem> get items => _queue.items;

  /// The items in actual play order, for showing "up next".
  List<PlaylistItem> get orderedItems => _queue.ordered;
  int get currentIndex => _queue.index;
  Stream<Duration> get positionStream => player.positionStream;

  /// Called once at startup: the saved preferences (§5.1).
  Future<void> loadPreferences() async {
    _playMode = await prefs.playMode();
    await player.setSpeed(await prefs.speed());
  }

  /// Plays the list that was on screen at the moment of the tap (rule 4).
  Future<void> playItems(
    List<PlaylistItem> items, {
    int startIndex = 0,
    String? playlistId,
    bool autoPlay = true,
  }) async {
    if (items.isEmpty) return;
    // **The guard starts here rather than in `_loadCurrent`** (revealed by
    // the race test): there are two preference reads between this line and
    // `_loadCurrent`. A stop landing in between, from dismissing the mini
    // player, completed and then **this path carried on, built the queue
    // and played**, bringing back the bar the user had just closed.
    final generation = ++_generation;
    _playlistId = playlistId;
    _playMode = await prefs.playMode(playlistId: playlistId);
    final shuffle = await prefs.shuffle();
    if (_isStale(generation)) return;
    _consecutiveErrors = 0;
    _queue = PlaybackQueue(items: items, index: startIndex, shuffle: shuffle);
    _publishQueue();
    await _loadCurrent(autoPlay: autoPlay);
  }

  /// Revives the saved session after the app restarts, **without
  /// autoplaying**. The mini player appears so the user can continue with a
  /// tap.
  Future<bool> restoreSession() async {
    final generation = ++_generation;
    final snapshot = await stateStore.read();
    if (snapshot == null || snapshot.isEmpty) return false;
    _playlistId = snapshot.playlistId;
    _playMode = await prefs.playMode(playlistId: _playlistId);
    final shuffle = await prefs.shuffle();
    // The commands, from the notification, the lock screen and the
    // interface.
    //
    // **They stay in the class** and are not moved to a `part` file: an
    // extension does not override the original method, so `audio_service`
    // would have called `BaseAudioHandler`'s version instead. A correctness
    // bug found in the full review 2026-09-02.
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

  // The commands, from the notification, the lock screen and the interface.
  //
  // **They stay in the class** and are not moved to a `part` file: an
  // extension does not override the original method, so `audio_service`
  // would have called `BaseAudioHandler`'s version instead. A correctness
  // bug found in the full review 2026-09-02.

  @override
  Future<void> play() async {
    // **Play with nothing queued revives the session, or does nothing**
    // (field report 2026-09-25: "coming back after a while, the clip plays
    // on its own, outside the playlist, and next does nothing"). A stopped
    // queue is empty while the player still holds its last source, so a
    // play from the car or the earphones started that one clip with no
    // list around it. It now brings the saved list back first, and a
    // session the user closed by hand, which saves none, stays closed.
    if (_queue.isEmpty && !await restoreSession()) return;
    await _takeVideoFocus();
    await player.play();
  }

  /// **Silencing video does not cancel playback** (2026-09-03): the
  /// registrar is a screen that may already be gone, and a throw from it
  /// aborted `player.play()` before it began, so the app looked like it
  /// "plays nothing" after visiting reels (field report).
  Future<void> _takeVideoFocus() async {
    try {
      await onTakeVideoFocus?.call();
    } on Object {
      onTakeVideoFocus = null; // a dead registrar is not asked again
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
  Future<void> skipToPrevious() async {
    if (player.position > restartThreshold) {
      await player.seek(Duration.zero);
      _broadcast();
      return;
    }
    await _skip(forward: false);
  }

  /// A tap on an item in the queue sheet; [index] is an index into the
  /// items.
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

  /// **Trap §6.5**: stopping clears everything that keeps the mini player
  /// visible.
  @override
  Future<void> stop() => _stop(forgetSession: true);

  /// [forgetSession] is false only for the paused auto-stop: that one
  /// gives the phone its resources back, and must not also throw away the
  /// list someone paused and meant to come back to.
  Future<void> _stop({required bool forgetSession}) async {
    _generation++; // a pending load does not revive the mini player after it closes
    _pausedStopTimer?.cancel();
    _pausedStopTimer = null;
    await savePosition();
    // **The queue is emptied before the player is stopped**, because the
    // stop itself broadcasts — and a broadcast over a paused, non-empty
    // queue would arm the auto-stop timer again, a ghost that fires into
    // whatever session comes next.
    _queue = PlaybackQueue(items: const []);
    _wasPlaying = false;
    await player.stop();
    _playlistId = null;
    mediaItem.add(null);
    queue.add(const []);
    if (forgetSession) await stateStore.clear();
    playbackState.add(
      PlaybackState(processingState: AudioProcessingState.idle, playing: false),
    );
    await super.stop();
  }

  Future<void> dispose() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    _pausedStopTimer?.cancel();
    _pausedStopTimer = null;
    for (final sub in _subs) {
      await sub.cancel();
    }
    _subs.clear();
    await player.dispose();
  }

  // Internals.

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

  void _broadcast() {
    final playing = player.playing;
    playingNotifier.value = playing;
    _syncPausedStop(playing: playing);
    playbackState.add(
      playbackState.value.copyWith(
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
      ),
    );
  }
}
