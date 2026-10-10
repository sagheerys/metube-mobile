import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../models/playlist_item.dart';
import '../playback/audio_handler.dart';
import '../video/video_side_panel.dart';
import 'mt_up_next_list.dart';

/// What is playing, read along beside the controls: the app's companion
/// for the current item (a transcript, in Super) and the queue, as two
/// tabs.
///
/// It lives wherever a tablet has room for it next to the player: the side
/// panel beside the library, the second column of the full player held
/// sideways, and under the controls held upright. A phone never shows it;
/// there the same two open as sheets from their buttons.
class MTNowPlayingTabs extends StatefulWidget {
  const MTNowPlayingTabs({
    super.key,
    required this.handler,
    this.artwork,
    this.companion,
  });

  final MTAudioHandler handler;
  final MTArtworkBuilder? artwork;

  /// Asked again for each item as the queue moves. Null, or a null answer,
  /// leaves the queue as the only tab.
  final MTVideoPanel? Function(PlaylistItem item)? companion;

  @override
  State<MTNowPlayingTabs> createState() => _MTNowPlayingTabsState();
}

class _MTNowPlayingTabsState extends State<MTNowPlayingTabs> {
  /// The reader's choice. The companion opens first when an item has one:
  /// it is the reason to keep the panel open at all.
  bool _queue = false;

  MTAudioHandler get _handler => widget.handler;

  @override
  Widget build(BuildContext context) => StreamBuilder<MediaItem?>(
    stream: _handler.mediaItem,
    builder: (context, _) {
      final item = _handler.currentItem;
      if (item == null) return const SizedBox.shrink();
      final pane = widget.companion?.call(item);
      final showQueue = _queue || pane == null;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: MTSpace.xs,
            runSpacing: MTSpace.xs,
            children: [
              if (pane != null)
                _Tab(
                  icon: pane.icon,
                  label: pane.label,
                  selected: !showQueue,
                  onTap: () => setState(() => _queue = false),
                ),
              _Tab(
                icon: Icons.queue_music_rounded,
                label: '${context.mtl.upNext} · ${_handler.items.length}',
                selected: showQueue,
                onTap: () => setState(() => _queue = true),
              ),
            ],
          ),
          const SizedBox(height: MTSpace.sm),
          Expanded(
            child: showQueue
                ? _queueList()
                // Keyed by the item, so the next clip gets its own
                // transcript rather than the last one's scroll and search.
                : KeyedSubtree(
                    key: ValueKey(item.canonicalUrl),
                    child: pane.builder(
                      context,
                      () => setState(() => _queue = true),
                    ),
                  ),
          ),
        ],
      );
    },
  );

  Widget _queueList() => ListenableBuilder(
    listenable: _handler.playingNotifier,
    builder: (context, _) {
      final ordered = _handler.orderedItems;
      final currentUrl = _handler.currentItem?.canonicalUrl;
      return MTUpNextList(
        items: ordered,
        currentIndex: ordered.indexWhere((i) => i.canonicalUrl == currentUrl),
        artwork: widget.artwork,
        paused: !_handler.playingNotifier.value,
        revealCurrent: true,
        onTap: (index) =>
            _handler.skipToQueueItem(_handler.items.indexOf(ordered[index])),
      );
    },
  );
}

/// A tab drawn like the library's filter chips: the chosen one inverted.
class _Tab extends StatelessWidget {
  const _Tab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final fg = selected ? p.bg : p.ink2;
    final radius = BorderRadius.circular(MTRadius.chip);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? p.ink : p.card,
        borderRadius: radius,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MTSpace.md,
              vertical: MTSpace.xs,
            ),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: selected ? p.ink : p.line2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 15, color: fg),
                const SizedBox(width: MTSpace.xxs),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelMedium!.copyWith(
                    color: fg,
                    fontWeight: selected ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
