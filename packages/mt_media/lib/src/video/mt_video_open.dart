import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:video_player/video_player.dart';

import '../models/playback_source.dart';

/// Opens and prepares a clip's player.
///
/// **Some hardware decoders refuse the texture path.** Flutter draws a video
/// through an `ImageReader`, and an older MediaTek decoder (an Android 10
/// tablet, measured 2026-10-10) cannot allocate the buffers that asks for:
/// every H.264 clip failed to start with "Failed to allocate buffers", while
/// AV1, decoded in software, played. Drawn into a plain Android surface (a
/// platform view) the same clip plays at once.
///
/// The texture stays the first choice, because it composes for less and
/// every device that works today keeps exactly what it had. A device whose
/// decoder refuses it once switches for the rest of the run, so only its
/// first clip pays for the second attempt.
abstract final class MTVideoOpen {
  /// Whether this device has shown that it needs the platform view.
  static bool platformView = false;

  static VideoViewType get _viewType =>
      platformView ? VideoViewType.platformView : VideoViewType.textureView;

  /// A prepared controller, or the error of the last attempt.
  static Future<VideoPlayerController> prepare(PlaybackSource source) async {
    final controller = _create(source);
    try {
      await controller.initialize();
      return controller;
    } on PlatformException catch (error) {
      await controller.dispose();
      if (platformView || !refusedSurface(error)) rethrow;
    }
    platformView = true;
    final retry = _create(source);
    try {
      await retry.initialize();
      return retry;
    } on Object {
      await retry.dispose();
      rethrow;
    }
  }

  /// A video decoder that would not start, as opposed to a network or file
  /// error, which a second surface cannot fix and would only make slower.
  @visibleForTesting
  static bool refusedSurface(PlatformException error) =>
      '${error.message} ${error.details}'.contains('MediaCodecVideoRenderer');

  static VideoPlayerController _create(PlaybackSource source) => source.isLocal
      ? VideoPlayerController.file(
          File(source.uri.toFilePath()),
          viewType: _viewType,
        )
      : VideoPlayerController.networkUrl(
          source.uri,
          httpHeaders: source.headers,
          viewType: _viewType,
        );
}

/// [VideoPlayer], with one repair for the platform view.
///
/// A platform view binds the player to its own surface and unbinds it when
/// it closes. The full-screen page shows the same player above this one,
/// so on leaving it the player was left with no surface: the sound went on
/// over a black frame. This view builds a fresh surface whenever its page
/// comes back to the front. The texture needs none of that and is left as
/// it was.
class MTVideoView extends StatefulWidget {
  const MTVideoView(this.controller, {super.key});

  final VideoPlayerController controller;

  @override
  State<MTVideoView> createState() => _MTVideoViewState();
}

class _MTVideoViewState extends State<MTVideoView> {
  Animation<double>? _covered;
  int _surface = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final covered = ModalRoute.of(context)?.secondaryAnimation;
    if (covered == _covered) return;
    _covered?.removeStatusListener(_onCovered);
    _covered = covered?..addStatusListener(_onCovered);
  }

  void _onCovered(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || !mounted) return;
    if (widget.controller.viewType != VideoViewType.platformView) return;
    setState(() => _surface++);
  }

  @override
  void dispose() {
    _covered?.removeStatusListener(_onCovered);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      VideoPlayer(widget.controller, key: ValueKey(_surface));
}
