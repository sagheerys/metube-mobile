import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models/playback_source.dart';
import 'mt_video_codec.dart';

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
/// decoder refuses it, and then plays in the platform view, switches for
/// the rest of the run, so only its first clip pays for the second attempt.
///
/// **AV1 always opens in the platform view**, on every device: see
/// [MTVideoCodec] for the picture it draws on the texture. H.264 and VP9,
/// which most clips are, keep the texture.
abstract final class MTVideoOpen {
  /// Whether this device has shown that it needs the platform view.
  static bool platformView = false;

  /// A prepared controller, or the error of the last attempt.
  ///
  /// [audioOnly] (a song in the video player) always takes the texture:
  /// the plugin's platform view reads the video track as the player
  /// becomes ready and crashes the app when there is none, and a song has
  /// no picture for either surface to draw.
  static Future<VideoPlayerController> prepare(
    PlaybackSource source, {
    bool audioOnly = false,
  }) async {
    final surface =
        !audioOnly && (platformView || await MTVideoCodec.isAv1(source))
        ? VideoViewType.platformView
        : VideoViewType.textureView;
    final controller = _create(source, surface);
    try {
      await controller.initialize();
      return controller;
    } on PlatformException catch (error) {
      await controller.dispose();
      if (audioOnly ||
          surface == VideoViewType.platformView ||
          !refusedSurface(error)) {
        rethrow;
      }
    } on Object {
      // No caller disposes a controller it never received.
      await controller.dispose();
      rethrow;
    }
    final retry = _create(source, VideoViewType.platformView);
    try {
      await retry.initialize();
      // Remembered only once it has worked: a file no decoder can play
      // fails both ways, and must not move a healthy device off the texture.
      platformView = true;
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

  static VideoPlayerController _create(
    PlaybackSource source,
    VideoViewType viewType,
  ) => source.isLocal
      ? VideoPlayerController.file(
          File(source.uri.toFilePath()),
          viewType: viewType,
        )
      : VideoPlayerController.networkUrl(
          source.uri,
          httpHeaders: source.headers,
          viewType: viewType,
        );
}

/// The route full screen opens in.
///
/// **No fade for a platform view.** Its picture lives in one place at a
/// time: the full-screen page takes it, and the player beneath gets it
/// back only once that page is gone (see [MTVideoView]). A fade on leaving
/// showed the player beneath with no picture for the length of the fade,
/// then the picture popping in: an odd dimming on every AV1 clip, which is
/// most of YouTube. Without the fade, the gap is the moment a new surface
/// takes. The texture shows the picture on both pages at once, so it keeps
/// the usual transition.
Route<void> mtFullscreenRoute(
  VideoPlayerController? controller,
  WidgetBuilder builder,
) => controller?.viewType == VideoViewType.platformView
    ? PageRouteBuilder<void>(
        pageBuilder: (context, _, _) => builder(context),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      )
    : MaterialPageRoute<void>(builder: builder);

/// [VideoPlayer], with one repair for the platform view.
///
/// A platform view binds the player to its own surface and unbinds it when
/// it closes. The full-screen page shows the same player above this one,
/// so on leaving it the player was left with no surface: the sound went on
/// over a black frame. This view builds a fresh surface whenever its page
/// comes back to the front.
///
/// **It also steps aside while its page leaves.** Android's surface takes
/// no part in a fade: going back to the library, the page faded and the
/// picture stayed whole over it to the last frame. The picture is dropped
/// as the page starts to leave, so the frame fades with everything else,
/// and comes back on a fresh surface if the leaving is called off (a back
/// gesture let go). The texture needs none of that and is left as it was.
class MTVideoView extends StatefulWidget {
  const MTVideoView(this.controller, {super.key});

  final VideoPlayerController controller;

  @override
  State<MTVideoView> createState() => _MTVideoViewState();
}

class _MTVideoViewState extends State<MTVideoView> {
  Animation<double>? _covered;
  Animation<double>? _shown;
  int _surface = 0;
  bool _leaving = false;

  bool get _platform =>
      widget.controller.viewType == VideoViewType.platformView;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    final covered = route?.secondaryAnimation;
    if (covered != _covered) {
      _covered?.removeStatusListener(_onCovered);
      _covered = covered?..addStatusListener(_onCovered);
    }
    final shown = route?.animation;
    if (shown != _shown) {
      _shown?.removeStatusListener(_onShown);
      _shown = shown?..addStatusListener(_onShown);
    }
  }

  void _onCovered(AnimationStatus status) {
    if (status != AnimationStatus.dismissed || !mounted || !_platform) return;
    setState(() => _surface++);
  }

  void _onShown(AnimationStatus status) {
    if (!mounted || !_platform) return;
    final leaving = status == AnimationStatus.reverse;
    if (leaving == _leaving) return;
    setState(() {
      _leaving = leaving;
      if (!leaving) _surface++;
    });
  }

  @override
  void dispose() {
    _covered?.removeStatusListener(_onCovered);
    _shown?.removeStatusListener(_onShown);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _leaving
      ? const SizedBox.expand()
      : VideoPlayer(widget.controller, key: ValueKey(_surface));
}
