import '../models/playlist_item.dart';

/// What an app may ask of the reel on screen: which clip, where it is, and
/// to jump. The reels player owns its video and keeps it to itself; an app
/// that shows something in step with the clip, such as a transcript,
/// reads it through this.
///
/// Given to [MTReelsPlayer.handle] and filled in by the player while it is
/// alive: before that, and after it closes, there is no clip, the time is
/// zero and a jump does nothing.
class MTReelsHandle {
  PlaylistItem? Function()? _current;
  Duration Function()? _position;
  Future<void> Function(Duration to)? _seek;

  PlaylistItem? get current => _current?.call();
  Duration get position => _position?.call() ?? Duration.zero;
  Future<void> seek(Duration to) => _seek?.call(to) ?? Future.value();

  /// Called by the player alone.
  void attach({
    required PlaylistItem? Function() current,
    required Duration Function() position,
    required Future<void> Function(Duration to) seek,
  }) {
    _current = current;
    _position = position;
    _seek = seek;
  }

  /// Called by the player alone, as it closes.
  void detach() {
    _current = null;
    _position = null;
    _seek = null;
  }
}
