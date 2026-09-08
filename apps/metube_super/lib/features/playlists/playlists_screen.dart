import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../library/artwork_view.dart';
import '../library/library_providers.dart';
import '../player/playback_providers.dart';
import '../shared/error_report.dart';
import '../tags/manage_tags_sheet.dart';
import 'playlist_dialogs.dart';
import 'playlists_providers.dart';
import 'widgets/playlist_cards.dart';

/// تبويب القوائم (م-37): ذكية مثبتة ← قوائمك ← وسومك.
class PlaylistsScreen extends ConsumerWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final smart = ref.watch(smartListsProvider);
    final playlists = ref.watch(playlistsProvider);
    final tags = ref.watch(tagCountsProvider);

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
              title: l10n.errorGeneric('') ,
              message: l10n.tryAgain,
            ),
            data: (all) => _Grid(playlists: all),
          ),
          const SizedBox(height: MTSpace.xl),
          MTSectionHeader(
            title: l10n.yourTags,
            trailing: l10n.tagsOpenFiltered,
          ),
          const SizedBox(height: MTSpace.sm),
          tags.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (counts) => _TagChips(counts: counts),
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
    final library = ref.watch(libraryItemsProvider).valueOrNull ?? const [];
    final byUrl = {for (final item in library) item.canonicalUrl: item};
    final headers = ref.read(apiClientProvider)?.streamingHeaders;

    List<Widget> coversOf(SavedPlaylist playlist) => [
          for (final entry in playlist.items.take(4))
            if ((byUrl[entry.canonicalUrl]?.thumbnail ?? entry.cachedThumb)
                case final String url)
              ?artworkFor(url, headers: headers),
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

/// رقاقات «وسومك» بعدادات — نقرة تفتح المكتبة مصفّاة (م-37/ج).
class _TagChips extends ConsumerWidget {
  const _TagChips({required this.counts});

  final Map<String, int> counts;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    if (counts.isEmpty) {
      return Text(l10n.noTagsYet,
          style: Theme.of(context).textTheme.bodySmall);
    }
    final names = counts.keys.toList()..sort();
    return Wrap(
      spacing: MTSpace.xs + 1,
      runSpacing: MTSpace.xs + 1,
      children: [
        for (final tag in names)
          _TagChip(
            label: '# $tag',
            count: counts[tag],
            onTap: () {
              ref.read(libraryViewProvider.notifier).setTag(tag);
              context.go('/');
            },
          ),
        _TagChip(
          label: l10n.manageTags,
          manage: true,
          onTap: () => showManageTagsSheet(context, ref),
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.label,
    required this.onTap,
    this.count,
    this.manage = false,
  });

  final String label;
  final VoidCallback onTap;
  final int? count;
  final bool manage;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return Material(
      color: manage ? Colors.transparent : p.offlineSoft,
      borderRadius: BorderRadius.circular(MTRadius.chip),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(MTRadius.chip),
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: MTSpace.md, vertical: MTSpace.xs + 1),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(MTRadius.chip),
            border: manage ? Border.all(color: p.line2) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium!.copyWith(
                    color: manage ? p.ink2 : p.offlineInk),
              ),
              if (count != null) ...[
                const SizedBox(width: MTSpace.xs),
                Text('$count',
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        color: p.offlineInk.withValues(alpha: 0.7))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

