import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/library_data.dart';
import '../../di.dart';
import '../../router.dart';
import '../../shell/shell_state.dart';
import '../library/platform_label.dart';
import 'clip_action_row.dart';
import 'clip_actions.dart';
import 'clip_chapters.dart';
import 'clip_facts.dart';
import 'clip_menu.dart';
import 'clip_stage.dart';
import 'clip_state.dart';

/// One clip: its picture in the content (a 16:9 stage, or a 9:16 column
/// for a short), its title, and what can be done with it. The side panel
/// beside follows it with the transcript.
///
/// **A short is watched in its lane**: ↑/↓ or the wheel move to the next
/// short of the list it came from, each one loops, and a double click
/// marks it a favourite. There is no swipe player on a computer.
///
/// F11 fills the screen, Esc comes back.
class ClipPage extends ConsumerStatefulWidget {
  const ClipPage({super.key, required this.canonicalUrl});

  final String canonicalUrl;

  @override
  ConsumerState<ClipPage> createState() => _ClipPageState();
}

class _ClipPageState extends ConsumerState<ClipPage> {
  late final MTPlayer _player = ref.read(playerProvider);
  DateTime _lastWheel = DateTime.fromMillisecondsSinceEpoch(0);
  late final StreamSubscription<MTPlayerState> _follow;
  String? _playing;

  /// The clip this page shows, as last built.
  String? _shown;

  /// One wheel notch is one short; a flick of the wheel sends a burst.
  static const _wheelPause = Duration(milliseconds: 350);

  @override
  void initState() {
    super.initState();
    // Taken now, not when first read: the first change would otherwise be
    // compared with itself.
    _playing = _player.state.current?.canonicalUrl;
    _follow = _player.states.listen(_onPlayer);
  }

  @override
  void dispose() {
    unawaited(_follow.cancel());
    // The loop belongs to watching shorts here; left playing in the bar,
    // the lane moves on by itself.
    unawaited(_player.setLooping(false));
    super.dispose();
  }

  /// **The page goes with the player**: watching the clip that plays, a
  /// next, a previous or the end of the clip opens the clip that follows,
  /// as a video site does. It stayed behind on the cover of the clip that
  /// had ended, which read as a picture frozen while the sound went on.
  /// A short to a short stays in the lane, which follows by itself.
  void _onPlayer(MTPlayerState state) {
    final now = state.current;
    final was = _playing;
    _playing = now?.canonicalUrl;
    if (now == null || now.canonicalUrl == was || was != _shown) return;
    if (_inLane && now.isShortForm) return;
    if (mounted) GoRouter.of(context).go(EmberRoutes.item(now.canonicalUrl));
  }

  /// The page was opened on a short, so its lane follows the player.
  bool _inLane = false;

  void _fullScreen(bool on) =>
      ref.read(windowControlsProvider).setFullScreen(on);

  void _onWheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final now = DateTime.now();
    if (now.difference(_lastWheel) < _wheelPause) return;
    _lastWheel = now;
    unawaited(
      event.scrollDelta.dy > 0
          ? _player.skipToNext()
          : _player.skipToPrevious(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controls = ref.watch(windowControlsProvider);
    final library = ref.watch(libraryItemsProvider).valueOrNull ?? const [];
    return StreamBuilder<MTPlayerState>(
      stream: _player.states,
      initialData: _player.state,
      builder: (context, snap) {
        final current = (snap.data ?? _player.state).current;
        final listed = library
            .where((i) => i.canonicalUrl == widget.canonicalUrl)
            .firstOrNull;
        final opened = listed != null
            ? toPlaylistItem(listed)
            : current?.canonicalUrl == widget.canonicalUrl
            ? current
            : null;
        if (opened == null) {
          return Center(
            child: MTEmptyFrame(
              title: context.mtl.itemUnavailable,
              message: widget.canonicalUrl,
            ),
          );
        }
        // In the lane the page follows the player from short to short.
        final short = opened.isShortForm;
        _inLane = short;
        final item = short && (current?.isShortForm ?? false)
            ? current!
            : opened;
        _shown = item.canonicalUrl;
        final entry = library
            .where((i) => i.canonicalUrl == item.canonicalUrl)
            .firstOrNull;
        final isCurrent = current?.canonicalUrl == item.canonicalUrl;
        if (short && isCurrent) unawaited(_player.setLooping(true));
        final stage = ClipMenuArea(
          item: item,
          child: ClipStage(
            item: item,
            cover: entry?.thumbnail,
            isCurrent: isCurrent,
            audioOnly: ref.watch(audioOnlyProvider),
            onPlay: () => unawaited(_player.playItems([item])),
          ),
        );
        // Its keys (F11, Esc, and ↑/↓ between shorts) are the window's:
        // see EmberKeyboard.
        return ValueListenableBuilder<bool>(
          valueListenable: controls.fullScreen,
          builder: (context, full, _) => full
              ? _Shorts.wrap(short, stage, this)
              : short
              ? _ShortsLayout(
                  stage: _Shorts.wrap(true, stage, this),
                  item: item,
                )
              : _ClipLayout(
                  stage: stage,
                  item: item,
                  entry: entry,
                  isCurrent: isCurrent,
                  onFullScreen: () => _fullScreen(true),
                ),
        );
      },
    );
  }
}

/// A short's stage: the 9:16 column, the wheel and the double click.
abstract final class _Shorts {
  static Widget wrap(bool short, Widget stage, _ClipPageState page) {
    if (!short) return stage;
    return Listener(
      onPointerSignal: page._onWheel,
      child: GestureDetector(
        onDoubleTap: () {
          final url = page._player.state.current?.canonicalUrl;
          if (url != null) {
            unawaited(page.ref.read(clipActionsProvider).toggleFavorite(url));
          }
        },
        child: Center(
          child: AspectRatio(aspectRatio: 9 / 16, child: stage),
        ),
      ),
    );
  }
}

class _ShortsLayout extends StatelessWidget {
  const _ShortsLayout({required this.stage, required this.item});

  final Widget stage;
  final PlaylistItem item;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(MTSpace.xl),
      child: Column(
        children: [
          Expanded(child: stage),
          const SizedBox(height: MTSpace.md),
          Text(
            item.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            textDirection: mtTextDirectionOf(
              item.title,
              Directionality.of(context),
            ),
            style: text.titleSmall?.copyWith(color: p.ink),
          ),
          const SizedBox(height: MTSpace.xxs),
          Text(
            context.mtl.desktopShortsHint,
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(color: p.ink3),
          ),
        ],
      ),
    );
  }
}

class _ClipLayout extends ConsumerWidget {
  const _ClipLayout({
    required this.stage,
    required this.item,
    required this.entry,
    required this.isCurrent,
    required this.onFullScreen,
  });

  final Widget stage;
  final PlaylistItem item;
  final LibraryItem? entry;
  final bool isCurrent;
  final VoidCallback onFullScreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final audioOnly = ref.watch(audioOnlyProvider);
    final theater = ref.watch(theaterProvider);
    final url = item.canonicalUrl;
    final meta = mtMetaLine([
      ?item.uploader,
      platformLabel(l, MediaPlatform.detect(url)),
      if (item.duration case final d?) mtFormatDuration(d),
    ]);
    return LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        padding: const EdgeInsets.all(MTSpace.xl),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: stageWidth(
                box.maxWidth,
                box.maxHeight,
                theater: theater && !item.isAudio,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(aspectRatio: 16 / 9, child: stage),
                const SizedBox(height: MTSpace.lg),
                // The title reads in its own text's direction but aligns to the
                // interface's start edge, across the player's full width.
                // Selectable, to copy it (owner's request 2026-11-11).
                MTForeignText(
                  item.title,
                  overflow: null,
                  selectable: true,
                  style: text.titleLarge?.copyWith(color: p.ink),
                ),
                const SizedBox(height: MTSpace.xxs),
                Text(meta, style: text.bodySmall?.copyWith(color: p.ink3)),
                if (entry case final entry?)
                  ClipFacts(
                    entry: entry,
                    picture: isCurrent && !item.isAudio && !audioOnly,
                  ),
                const SizedBox(height: MTSpace.md),
                ClipActionRow(
                  item: item,
                  entry: entry,
                  isCurrent: isCurrent,
                  onFullScreen: onFullScreen,
                ),
                ClipChapters(item: item, isCurrent: isCurrent),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
