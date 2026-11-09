import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../di.dart';
import '../router.dart';
import '../features/clip/clip_state.dart';
import '../features/library/artwork.dart';
import 'shell_state.dart';
import 'video_surface.dart';
import 'window_controls.dart';

/// The small card's two sizes: sound alone, and a picture at 16:9. The
/// picture is where it starts: its edges stretch it up to half the screen.
abstract final class EmberMiniSize {
  static const audio = Size(360, 96);
  static const video = Size(360, 203);
}

/// The clip whose page was open on the clip playing when the card took the
/// window's place; null when another page was.
String? _miniFrom;

/// Ctrl+M and the player bar's button: the small card above every window,
/// sized for what plays, or the full window again.
///
/// **Back from the card, the page goes with the player**, as it does in
/// the window: the card stands in for the whole window, the clip's page
/// included, so a next pressed on the card went unheard and the window came
/// back on the clip that had ended, its cover still as a frozen picture.
void toggleMiniWindow(WidgetRef ref, GoRouter router) {
  final controls = ref.read(windowControlsProvider);
  final current = ref.read(playerProvider).state.current;
  if (controls.mini.value) {
    controls.setMini(null);
    final from = _miniFrom;
    _miniFrom = null;
    if (from != null && current != null && current.canonicalUrl != from) {
      router.go(EmberRoutes.item(current.canonicalUrl));
    }
    return;
  }
  final path = router.routerDelegate.currentConfiguration.uri.path;
  _miniFrom = current != null && path == EmberRoutes.item(current.canonicalUrl)
      ? current.canonicalUrl
      : null;
  final picture = miniShowsPicture(
    ref.read(playerProvider).state,
    audioOnly: ref.read(audioOnlyProvider),
  );
  controls.setMini(
    picture ? EmberMiniSize.video : EmberMiniSize.audio,
    stretch: picture,
  );
}

/// Whether the card shows a picture: a video playing with its picture on.
bool miniShowsPicture(MTPlayerState state, {required bool audioOnly}) {
  final item = state.current;
  return item != null && !item.isAudio && !audioOnly;
}

/// **The small card above every window** (Ctrl+M): what plays, play and
/// next, and a hairline of progress, in the mini player's colours (dark by
/// day, the card's by night). A video shows its picture. The card is
/// carried by any press on it; a double click, Ctrl+M or Esc brings the
/// full window back.
class EmberMiniWindow extends ConsumerStatefulWidget {
  const EmberMiniWindow({
    super.key,
    required this.player,
    required this.controls,
    required this.onRestore,
  });

  final MTPlayer player;
  final WindowControls controls;
  final VoidCallback onRestore;

  @override
  ConsumerState<EmberMiniWindow> createState() => _EmberMiniWindowState();
}

class _EmberMiniWindowState extends ConsumerState<EmberMiniWindow> {
  /// The size last asked of the window, so it is asked again only when
  /// what plays turns from sound to picture or back.
  Size? _asked;

  void _fit(Size size) {
    if (size == _asked) return;
    _asked = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.controls.mini.value) {
        widget.controls.setMini(size, stretch: size == EmberMiniSize.video);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final audioOnly = ref.watch(audioOnlyProvider);
    return StreamBuilder<MTPlayerState>(
      stream: widget.player.states,
      initialData: widget.player.state,
      builder: (context, snap) {
        final state = snap.data ?? widget.player.state;
        final picture = miniShowsPicture(state, audioOnly: audioOnly);
        _fit(picture ? EmberMiniSize.video : EmberMiniSize.audio);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: widget.onRestore,
          onPanStart: (_) => widget.controls.startDragging(),
          child: picture
              ? _Picture(state: state, widget: widget)
              : _Sound(state: state, widget: widget),
        );
      },
    );
  }
}

class _Sound extends ConsumerWidget {
  const _Sound({required this.state, required this.widget});

  final MTPlayerState state;
  final EmberMiniWindow widget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = MTThemeX.of(context).palette;
    final item = state.current;
    final side = EmberMiniSize.audio.height - MTSpace.xl;
    return ColoredBox(
      color: p.miniBg,
      child: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: MTSpace.sm),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      MTCorners.desktop.thumb,
                    ),
                    child: SizedBox.square(
                      dimension: side,
                      child:
                          artworkFor(
                            ref,
                            context,
                            item?.artworkUrl,
                            width: side,
                            height: side,
                          ) ??
                          ColoredBox(
                            color: p.miniInk.withValues(alpha: 0.12),
                            child: Center(
                              child: MTIcon(
                                MTIcons.headphones,
                                size: MTSpace.xl,
                                color: p.miniInkMuted,
                              ),
                            ),
                          ),
                    ),
                  ),
                  const SizedBox(width: MTSpace.sm),
                  Expanded(child: _Titles(item: item)),
                  _Buttons(state: state, widget: widget, ink: p.miniInk),
                ],
              ),
            ),
          ),
          _Progress(player: widget.player, state: state),
        ],
      ),
    );
  }
}

class _Picture extends ConsumerWidget {
  const _Picture({required this.state, required this.widget});

  final MTPlayerState state;
  final EmberMiniWindow widget;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ColoredBox(
      color: MTPalette.fullscreenScrim,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ref.watch(videoSurfaceProvider).build(context),
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // The buttons on the picture's own shade, as the clip
                // page's do.
                DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, MTPalette.fullscreenScrim],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(
                      start: MTSpace.sm,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _Titles(item: state.current, onPicture: true),
                        ),
                        _Buttons(
                          state: state,
                          widget: widget,
                          ink: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
                _Progress(player: widget.player, state: state),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Titles extends StatelessWidget {
  const _Titles({required this.item, this.onPicture = false});

  final PlaylistItem? item;

  /// White over a picture, the mini player's ink otherwise.
  final bool onPicture;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final ink = onPicture ? Colors.white : p.miniInk;
    final muted = onPicture ? Colors.white70 : p.miniInkMuted;
    final item = this.item;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          item?.title ?? context.mtl.desktopNothingPlaying,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textDirection: item == null
              ? null
              : mtTextDirectionOf(item.title, Directionality.of(context)),
          style: text.titleSmall?.copyWith(color: ink),
        ),
        if (item?.uploader case final who?)
          Text(
            who,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall?.copyWith(color: muted),
          ),
      ],
    );
  }
}

/// Play and next, and the way back to the full window. They keep the
/// direction of time in Arabic too, as the player bar's do.
class _Buttons extends StatelessWidget {
  const _Buttons({
    required this.state,
    required this.widget,
    required this.ink,
  });

  final MTPlayerState state;
  final EmberMiniWindow widget;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final player = widget.player;
    final live = !state.isEmpty;
    Widget button(MTIconData icon, String label, VoidCallback? onTap) =>
        MTShortcutTooltip(
          message: label,
          child: IconButton(
            onPressed: onTap,
            icon: MTIcon(
              icon,
              size: MTDensity.desktop.icon,
              color: onTap == null ? ink.withValues(alpha: 0.4) : ink,
              semanticLabel: label,
            ),
          ),
        );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(
            state.playing ? MTIcons.pause : MTIcons.playFill,
            state.playing ? l.pause : l.play,
            live
                ? () =>
                      unawaited(state.playing ? player.pause() : player.play())
                : null,
          ),
          button(
            MTIcons.next,
            l.next,
            live ? () => unawaited(player.skipToNext()) : null,
          ),
          button(MTIcons.fullscreen, l.desktopMiniRestore, widget.onRestore),
        ],
      ),
    );
  }
}

/// A hairline of the clip's progress along the card's foot.
class _Progress extends StatelessWidget {
  const _Progress({required this.player, required this.state});

  final MTPlayer player;
  final MTPlayerState state;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      initialData: player.position,
      builder: (context, snap) {
        final total = state.duration?.inMilliseconds ?? 0;
        final at = snap.data?.inMilliseconds ?? 0;
        // Drawn, not Material's bar: the hairline fills left to right as
        // the playback bar does, whatever the language.
        return SizedBox(
          height: _hairline,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: total <= 0 ? 0 : (at / total).clamp(0.0, 1.0),
              child: ColoredBox(color: p.accent),
            ),
          ),
        );
      },
    );
  }

  static const _hairline = 2.0;
}
