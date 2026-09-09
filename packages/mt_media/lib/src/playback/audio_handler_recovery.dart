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

  /// Automatically skips a broken item, and stops if the fault repeats
  /// rather than looping forever.
  ///
  /// **[autoPlay] is inherited from the path that called us (fix ع-5):** it
  /// used to be hard-coded to `true`, so if the first item of a restored
  /// session failed at startup, a deleted file or a server briefly
  /// unreachable, **the next item started playing out loud with no tap at
  /// all**, breaking the rule that restoration never autoplays.
  Future<void> _onError({bool autoPlay = true}) async {
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
