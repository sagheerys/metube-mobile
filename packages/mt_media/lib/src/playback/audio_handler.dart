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
  Future<void> skipToPrevious() => _skip(forward: false);

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
  Future<void> stop() async {
    _generation++; // a pending load does not revive the mini player after it closes
    await savePosition();
    await player.stop();
    _queue = PlaybackQueue(items: const []);
    _playlistId = null;
    mediaItem.add(null);
    queue.add(const []);
    await stateStore.clear();
    playbackState.add(
      PlaybackState(processingState: AudioProcessingState.idle, playing: false),
    );
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

  /// The clip ended naturally, so the mode decides what happens next.
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
    playingNotifier.value = playing;
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
