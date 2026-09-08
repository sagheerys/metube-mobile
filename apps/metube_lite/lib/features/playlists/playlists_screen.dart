import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../downloads_library/artwork_view.dart';
import '../downloads_library/library_providers.dart';
import '../player/playback_providers.dart';
import '../shared/error_report.dart';
import 'playlist_dialogs.dart';
import 'playlists_providers.dart';
import 'widgets/playlist_cards.dart';

/// تبويب القوائم (م-37) في Lite: **قسمان** — ذكية مثبتة ← قوائمك.
/// قسم «وسومك» ميزة Super (م-26) فلا وجود له هنا.
class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final smart = ref.watch(smartListsProvider);
    final playlists = ref.watch(playlistsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navPlaylists),
        actions: [
          IconButton(
            tooltip: l10n.createPlaylist,
            onPressed: () => showCreatePlaylistDialog(context, ref),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
            MTSpace.pagePad, 0, MTSpace.pagePad, 140),
        children: [
          MTSectionHeader(title: l10n.smartPlaylists),
          const SizedBox(height: MTSpace.sm),
          Row(
            children: [
              for (final list in smart) ...[
                if (list != smart.first) const SizedBox(width: MTSpace.xs + 2),
                Expanded(
                  child: SmartPlaylistCard(
                    kind: list.kind,
                    count: list.count,
                    onTap: () => _playSmart(context, ref, list),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: MTSpace.xl),
          MTSectionHeader(
            title: l10n.yourPlaylists,
            trailing: '${l10n.sortedByLastPlayed} ↓',
          ),
          const SizedBox(height: MTSpace.sm),
          playlists.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => MTEmptyState(
              icon: Icons.error_outline_rounded,
              title: l10n.tryAgain,
              message: l10n.noPlaylistsMessage,
            ),
            data: (all) => _Grid(playlists: all),
          ),
        ],
      ),
    );
  }

  /// نقرة قائمة ذكية ⇒ تشغيلها كاملة (ر-7 خطوة 1).
  Future<void> _playSmart(
      BuildContext context, WidgetRef ref, SmartList list) async {
    final items = [for (final item in list.items) toPlaylistItem(item)];
    final visual = await ref.read(playlistPlayerProvider).play(items);
    if (visual && context.mounted) context.push('/player');
  }
}

class _Grid extends ConsumerWidget {
  const _Grid({required this.playlists});

  final List<SavedPlaylist> playlists;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final library = ref.watch(localMediaProvider).valueOrNull ?? const [];
    final byKey = {for (final item in library) item.key: item};

    List<Widget> coversOf(SavedPlaylist playlist) => [
          for (final entry in playlist.items.take(4))
            if ((byKey[entry.canonicalUrl]?.thumbnail ?? entry.cachedThumb)
                case final String url)
              ?artworkFor(url),
        ];

    // حالة فارغة صريحة (تدقيق 8.1): بلاطة «+» وحدها لا تشرح شيئاً.
    if (playlists.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: MTSpace.sm),
            child: Text(
              l10n.noPlaylistsMessage,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall!
                  .copyWith(color: MTThemeX.of(context).palette.ink3),
            ),
          ),
          SizedBox(
            height: 150,
            child: _NewPlaylistTile(
              label: l10n.newPlaylistAction,
              onTap: () => showCreatePlaylistDialog(context, ref),
            ),
          ),
        ],
      );
    }

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: MTSpace.md - 1,
      crossAxisSpacing: MTSpace.md - 1,
      childAspectRatio: 0.78,
      children: [
        for (final playlist in playlists)
          PlaylistCard(
            playlist: playlist,
            thumbnails: coversOf(playlist),
            onTap: () => context.push('/playlists/${playlist.id}'),
            onPlay: () => _play(context, ref, playlist),
            onLongPress: () =>
                showPlaylistActionsSheet(context, ref, playlist),
          ),
        _NewPlaylistTile(
          label: l10n.newPlaylistAction,
          onTap: () => showCreatePlaylistDialog(context, ref),
        ),
      ],
    );
  }

  Future<void> _play(
      BuildContext context, WidgetRef ref, SavedPlaylist playlist) async {
    // **الفشل يُقال لا يُرمى**: بناء القائمة يمرّ بالمكتبة، والمكتبة
    // تمرّ بالسيرفر — فرفض الاعتماد كان يفلت من معالج اللمسة صامتاً.
    try {
      final items = await ref.read(playlistItemsProvider(playlist.id).future);
      final visual = await ref.read(playlistPlayerProvider).play(
            items,
            playlistId: playlist.id,
            playlistName: playlist.name,
          );
      if (visual && context.mounted) context.push('/player');
    } on MTApiException catch (e) {
      if (context.mounted) {
        showErrorSnack(context, ref, e, tag: 'playlist');
      }
    }
  }
}

class _NewPlaylistTile extends StatelessWidget {
  const _NewPlaylistTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(MTRadius.cardLg),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(MTRadius.cardLg),
          border: Border.all(color: p.line2, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: p.accentSoft,
                borderRadius: BorderRadius.circular(MTRadius.field - 1),
              ),
              child: Icon(Icons.add_rounded, size: 17, color: p.accentInk),
            ),
            const SizedBox(height: MTSpace.xs),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall!
                    .copyWith(color: p.ink3)),
          ],
        ),
      ),
    );
  }
}
