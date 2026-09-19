part of 'audio_handler.dart';

/// **Recovery and continuity**: the policy for skipping a broken item, and
/// saving the position and the session snapshot.
///
/// **A `part` file rather than its own library** (rule 4, the size limit):
/// these functions work on the private queue (`_queue`,
/// `_consecutiveErrors`), and an extension in another library cannot reach
/// private members.
extension MTAudioHandlerRecovery on MTAudioHandler {
  /// The maximum number of consecutive skips before giving up. A systemic
  /// fault, a dead network or blocked cleartext, fails every item, and
  /// marching silently through a hundred of them is worse than stopping
  /// plainly.
  static const int maxConsecutiveSkips = 5;

  /// The clip ended naturally, so the mode decides what happens next.
  ///
  /// **Lives here rather than in the class** for the size limit (rule 4):
  /// deciding what follows an item is continuity, which is this file's
  /// subject.
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

  /// **A paused session stops itself after [pausedAutoStop].**
  ///
  /// Driven by the broadcast rather than by [MTAudioHandler.pause], on
  /// purpose: a phone call pauses the player from **inside** the playback
  /// package, without passing through the handler at all, and that is
  /// precisely the case this has to cover. Called on every broadcast, so it
  /// must stay idempotent — an already-running timer is never restarted, or
  /// it would never fire.
  void _syncPausedStop({required bool playing}) {
    if (playing) _wasPlaying = true;
    if (playing || _queue.isEmpty || !_wasPlaying) {
      _pausedStopTimer?.cancel();
      _pausedStopTimer = null;
      return;
    }
    _pausedStopTimer ??= Timer(pausedAutoStop, () => unawaited(stop()));
  }

  /// Is this worth waiting for rather than skipping past?
  ///
  /// **The source decides, not the error text.** A stream can fail for a
  /// dropped network, a frozen process or a tunnel hiccup, all of which
  /// come back; a local file that will not open is broken and waiting for
  /// it is waiting forever. Re-resolving is cheap and synchronous, and it
  /// answers for the item as it stands **now**: a local copy deleted from
  /// under us already resolves to a stream.
  bool _isRetryableSource() {
    final item = _queue.current;
    if (item == null) return false;
    return resolver.resolve(item)?.origin == PlaybackOrigin.stream;
  }

  /// Automatically skips a broken item, and stops if the fault repeats
  /// rather than looping forever.
  ///
  /// **A stream is retried before it is given up on** (measured
  /// 2026-09-19): a phone call left the process frozen with its network
  /// cut, the next item failed with `SocketTimeoutException`, and the skip
  /// path then walked the queue and stopped the session — a minute of
  /// silence for a hiccup that had already passed. Now the same item is
  /// loaded again after each of [networkRetryBackoff], and only a source
  /// that fails every time is treated as broken.
  ///
  /// **[autoPlay] is inherited from the path that called us:** it
  /// used to be hard-coded to `true`, so if the first item of a restored
  /// session failed at startup, a deleted file or a server briefly
  /// unreachable, **the next item started playing out loud with no tap at
  /// all**, breaking the rule that restoration never autoplays.
  Future<void> _onError({bool autoPlay = true}) async {
    if (_networkRetries < networkRetryBackoff.length && _isRetryableSource()) {
      final generation = _generation;
      final wait = networkRetryBackoff[_networkRetries];
      _networkRetries++;
      await Future<void>.delayed(wait);
      // A stop, or another item chosen while we waited, wins.
      if (_isStale(generation)) return;
      return _loadCurrent(autoPlay: autoPlay);
    }
    _networkRetries = 0;
    _consecutiveErrors++;
    if (_queue.isEmpty ||
        _consecutiveErrors >= _queue.length ||
        _consecutiveErrors >= maxConsecutiveSkips) {
      return stop();
    }
    if (_queue.moveNext(PlayMode.repeatAll)) {
      await _loadCurrent(autoPlay: autoPlay);
    } else {
      await stop();
    }
  }

  void _publishQueue() =>
      queue.add([for (final item in _queue.ordered) item.toMediaItem()]);

  Future<void> savePosition() async {
    final item = _queue.current;
    if (item == null) return;
    await positions.save(
      item.canonicalUrl,
      player.position,
      duration: player.duration,
    );
  }

  /// Periodic saving: the position plus the session snapshot.
  Future<void> persist() async {
    if (_queue.isEmpty) return;
    await savePosition();
    await stateStore.write(
      AudioSessionSnapshot(
        items: _queue.items,
        index: _queue.index,
        position: player.position,
        playlistId: _playlistId,
      ),
    );
  }

  Future<void> _loadCurrent({required bool autoPlay, Duration? startAt}) async {
    final generation = ++_generation;
    final item = _queue.current;
    if (item == null) return stop();
    final source = resolver.resolve(item);
    if (source == null) return _onError(autoPlay: autoPlay);

    mediaItem.add(item.toMediaItem());
    final resume =
        startAt ??
        await positions.positionOf(item.canonicalUrl) ??
        Duration.zero;
    if (_isStale(generation)) return;
    try {
      if (autoPlay) await _takeVideoFocus();
      if (_isStale(generation)) return;
      await player.setSource(source, initialPosition: resume);
      if (_isStale(generation)) return;
      _consecutiveErrors = 0;
      _networkRetries = 0;
      final duration = player.duration;
      if (duration != null) {
        mediaItem.add(item.toMediaItem().copyWith(duration: duration));
      }
      if (autoPlay) await player.play();
      if (_isStale(generation)) return;
      _broadcast();
      await persist();
    } on Object {
      if (_isStale(generation)) return;
      await _onError(autoPlay: autoPlay);
    }
  }

  /// Has a newer load, or a stop, overtaken us? If so we touch no shared
  /// state afterwards.
  bool _isStale(int generation) => generation != _generation;
}
