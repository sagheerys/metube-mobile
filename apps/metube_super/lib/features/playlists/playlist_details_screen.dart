import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../library/artwork_view.dart';
import '../home/add_flow.dart' show platformKindOf;
import 'playlist_dialogs.dart';
import 'playlists_providers.dart';

/// A saved playlist's details (rule 7, step 2): play all, shuffle, and the
/// headphones button. Drag to reorder, delete an item **with an undo**, and
/// an indicator for the current one.
class PlaylistDetailsScreen extends ConsumerWidget {
  const PlaylistDetailsScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final playlists = ref.watch(playlistsProvider).valueOrNull ?? const [];
    final playlist = playlists.where((p) => p.id == playlistId).firstOrNull;
    final itemsAsync = ref.watch(playlistViewProvider(playlistId));

    if (playlist == null) {
      return Scaffold(
        appBar: AppBar(),
        body: MTEmptyState(
          icon: Icons.queue_music_rounded,
          title: l10n.playlistDetails,
          message: l10n.noPlaylistsMessage,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          IconButton(
            tooltip: l10n.rename,
            onPressed: () => showPlaylistActionsSheet(context, ref, playlist),
            icon: const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => MTEmptyState(
          icon: Icons.error_outline_rounded,
          title: l10n.tryAgain,
          message: l10n.emptyPlaylistMessage,
        ),
        data: (view) => view.items.isEmpty
            ? MTEmptyState(
                icon: Icons.queue_music_outlined,
                title: l10n.emptyPlaylist,
                message: l10n.emptyPlaylistMessage,
              )
            : Column(
                children: [
                  _Actions(playlist: playlist, view: view),
                  Expanded(
                    child: _ReorderableItems(
                      playlistId: playlistId,
                      view: view,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.playlist, required this.view});

  final SavedPlaylist playlist;
  final PlaylistView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;

    Future<void> start({bool shuffle = false, bool audioOnly = false}) async {
      // **A missing item never enters the queue**: its source fails and the
      // player jumps to the next one, so the tap looks as though it played
      // something else (field report 2026-09-04).
      final visual = await ref
          .read(playlistPlayerProvider)
          .play(
            view.playable,
            playlistId: playlist.id,
            playlistName: playlist.name,
            shuffle: shuffle,
            audioOnly: audioOnly,
          );
      if (visual && context.mounted) context.push('/player');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MTSpace.pagePad,
        MTSpace.sm,
        MTSpace.pagePad,
        MTSpace.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: start,
              icon: const Icon(Icons.play_arrow_rounded, size: 18),
              label: Text(l10n.playAll),
            ),
          ),
          const SizedBox(width: MTSpace.xs),
          IconButton.outlined(
            tooltip: l10n.shuffle,
            onPressed: () => start(shuffle: true),
            icon: const Icon(Icons.shuffle_rounded, size: 19),
          ),
          const SizedBox(width: MTSpace.xs),
          // The headphones button: the whole playlist as background audio
          // even when it contains video.
          IconButton.outlined(
            tooltip: l10n.listenInBackground,
            onPressed: () => start(audioOnly: true),
            icon: Icon(Icons.headphones_rounded, size: 19, color: p.accent),
          ),
        ],
      ),
    );
  }
}

class _ReorderableItems extends ConsumerWidget {
  const _ReorderableItems({required this.playlistId, required this.view});

  final String playlistId;
  final PlaylistView view;

  List<PlaylistItem> get items => view.items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final headers = ref.read(apiClientProvider)?.streamingHeaders;
    // **The indicator used to stick on the first clip** (screenshot
    // 2026-09-02, defect ط-8): `ref.watch(audioHandlerProvider)` watches a
    // provider pinned by an override that **never emits**, and
    // `currentItem` is a getter over mutable state, a one-off read
    // disguised as a subscription. The correct source is in the package
    // itself: the `handler.mediaItem` stream, whose id is the canonicalUrl.
    // **Current is one thing and playing is another**: the equaliser danced
    // over a paused clip because the screen knew only which item was
    // current (field report 2026-09-04). The two streams together separate
    // the states.
    final handler = ref.read(audioHandlerProvider);
    return StreamBuilder<String?>(
      stream: handler.currentKey,
      builder: (context, keySnapshot) => StreamBuilder<bool>(
        stream: handler.playingStream,
        initialData: true,
        builder: (context, playingSnapshot) => _list(
          context,
          ref,
          headers,
          keySnapshot.data,
          playingSnapshot.data ?? true,
        ),
      ),
    );
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    Map<String, String>? headers,
    String? playingUrl,
    bool isPlaying,
  ) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(
        MTSpace.pagePad,
        0,
        MTSpace.pagePad,
        140,
      ),
      itemCount: items.length,
      onReorderItem: (oldIndex, newIndex) async {
        await ref
            .read(playlistsStoreProvider)
            .reorderItem(playlistId, oldIndex, newIndex);
        ref.invalidate(playlistItemsProvider(playlistId));
        ref.invalidate(playlistsProvider);
      },
      itemBuilder: (context, index) {
        final item = items[index];
        final missing = view.isMissing(item);
        return Dismissible(
          key: ValueKey(item.canonicalUrl),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _removeWithUndo(context, ref, item, index),
          background: _DismissBackground(),
          child: MTMediaCard(
            key: ValueKey('card-${item.canonicalUrl}'),
            title: item.title,
            // A missing item says so itself rather than looking valid and
            // then failing.
            subtitle: missing ? context.mtl.itemUnavailable : item.uploader,
            playing: !missing && item.canonicalUrl == playingUrl,
            paused: !isPlaying,
            thumbnail: artworkFor(item.artworkUrl, headers: headers),
            platform: platformKindOf(MediaPlatform.detect(item.canonicalUrl)),
            compact: true,
            onTap: () => missing
                ? showMTSnack(
                    context,
                    context.mtl.itemUnavailable,
                    type: MTSnackType.error,
                  )
                : _playFrom(context, ref, item),
          ),
        );
      },
    );
  }

  /// **The index is computed within the playable items, not within the
  /// displayed ones**: a playlist with dead entries played the wrong item
  /// because the two indexes diverged.
  Future<void> _playFrom(
    BuildContext context,
    WidgetRef ref,
    PlaylistItem item,
  ) async {
    final playlist =
        (ref.read(playlistsProvider).valueOrNull ?? const <SavedPlaylist>[])
            .where((p) => p.id == playlistId)
            .firstOrNull;
    final playable = view.playable;
    final index = playable.indexWhere(
      (i) => i.canonicalUrl == item.canonicalUrl,
    );
    if (index < 0) return;
    final visual = await ref
        .read(playlistPlayerProvider)
        .play(
          playable,
          startIndex: index,
          playlistId: playlistId,
          playlistName: playlist?.name,
        );
    if (visual && context.mounted) context.push('/player');
  }

  /// Deleting an item **with an undo** (rule 7): the removal is restored
  /// exactly where it was.
  void _removeWithUndo(
    BuildContext context,
    WidgetRef ref,
    PlaylistItem item,
    int index,
  ) {
    final l10n = context.mtl;
    final store = ref.read(playlistsStoreProvider);
    final entry = PlaylistEntry(
      canonicalUrl: item.canonicalUrl,
      serverFilename: item.serverFilename,
      cachedTitle: item.title,
      cachedThumb: item.artworkUrl,
    );

    Future<void> refresh() async {
      ref.invalidate(playlistItemsProvider(playlistId));
      ref.invalidate(playlistsProvider);
    }

    store.removeItem(playlistId, item.canonicalUrl).then((_) => refresh());
    showMTSnack(
      context,
      l10n.removedFromPlaylist,
      actionLabel: l10n.undo,
      onAction: () async {
        await store.addItems(playlistId, [entry]);
        await store.reorderItem(
          playlistId,
          (await store.byId(playlistId))!.items.length - 1,
          index,
        );
        await refresh();
      },
    );
  }
}

class _DismissBackground extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Container(
      alignment: AlignmentDirectional.centerEnd,
      padding: const EdgeInsets.symmetric(horizontal: MTSpace.xl),
      color: p.err.withValues(alpha: 0.12),
      child: Icon(Icons.delete_outline_rounded, color: p.err),
    );
  }
}
