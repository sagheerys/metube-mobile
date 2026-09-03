import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../downloads_library/local_item.dart';
import 'playlist_dialogs.dart';
import 'playlists_providers.dart';

/// «أضف لقائمة» (م-25) — فردي أو جماعي (ر-6)، مع إنشاء قائمة من هنا.
void showAddToPlaylistSheet(
  BuildContext context,
  WidgetRef ref,
  List<LocalItem> items,
) {
  if (items.isEmpty) return;
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => _AddToPlaylistSheet(items: items),
  );
}

class _AddToPlaylistSheet extends ConsumerWidget {
  const _AddToPlaylistSheet({required this.items});

  final List<LocalItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final playlists = ref.watch(playlistsProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(MTSpace.pagePad),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              MTSectionHeader(
                title: l10n.addToPlaylist,
                trailing: l10n.queueItemsCount(items.length),
              ),
              const SizedBox(height: MTSpace.sm),
              Flexible(
                child: playlists.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (_, _) => Text(l10n.tryAgain),
                  data: (all) => ListView(
                    shrinkWrap: true,
                    children: [
                      for (final playlist in all)
                        _tile(context, ref, playlist),
                      if (all.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(MTSpace.lg),
                          child: Text(l10n.noPlaylistsMessage,
                              textAlign: TextAlign.center,
                              style:
                                  Theme.of(context).textTheme.bodySmall),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: MTSpace.sm),
              OutlinedButton.icon(
                onPressed: () => _createAndAdd(context, ref),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(l10n.newPlaylistAction),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// **علامة «مضاف مسبقاً»** (بلاغ المالك 2026-09-03): كانت الورقة تعرض
  /// كل القوائم متشابهة، فلا سبيل لمعرفة أين وضعتَ المقطع قبل قليل إلا
  /// بفتح كل قائمة. المخزن يمنع التكرار أصلاً — الناقص كان الإخبار.
  Widget _tile(BuildContext context, WidgetRef ref, SavedPlaylist playlist) {
    final l10n = context.mtl;
    final palette = MTThemeX.of(context).palette;
    final present = {for (final entry in playlist.items) entry.canonicalUrl};
    // المعيار: **كل** المحدد موجود — وإلا فللنقرة ما تضيفه.
    final already = items
        .every((item) => present.contains(toPlaylistEntry(item).canonicalUrl));
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        playlist.pinned
            ? Icons.push_pin_rounded
            : Icons.queue_music_rounded,
        color: palette.ink2,
      ),
      title: Text(playlist.name),
      subtitle: Text(already
          ? l10n.alreadyInPlaylist
          : l10n.queueItemsCount(playlist.items.length)),
      trailing: already
          ? Icon(Icons.check_circle_rounded, color: palette.accent)
          : null,
      onTap: () => _add(context, ref, playlist, already: already),
    );
  }

  Future<void> _add(
    BuildContext context,
    WidgetRef ref,
    SavedPlaylist playlist, {
    bool already = false,
  }) async {
    Navigator.pop(context);
    await ref.read(playlistsStoreProvider).addItems(
          playlist.id,
          [for (final item in items) toPlaylistEntry(item)],
        );
    ref.invalidate(playlistsProvider);
    ref.invalidate(playlistItemsProvider(playlist.id));
    if (context.mounted) {
      showMTSnack(
        context,
        already
            ? context.mtl.alreadyInPlaylist
            : (items.length == 1
                ? context.mtl.videoAdded
                : context.mtl.addedToPlaylistCount(items.length)),
        type: MTSnackType.success,
      );
    }
  }

  Future<void> _createAndAdd(BuildContext context, WidgetRef ref) async {
    final name = await promptPlaylistName(context);
    if (name == null || name.isEmpty) return;
    final playlist = await ref.read(playlistsStoreProvider).create(
          name,
          items: [for (final item in items) toPlaylistEntry(item)],
        );
    ref.invalidate(playlistsProvider);
    if (context.mounted) {
      Navigator.pop(context);
      showMTSnack(context, context.mtl.playlistCreated,
          type: MTSnackType.success);
    }
    // القائمة الجديدة قد تُفتح فوراً من التبويب — لا انتقال تلقائي.
    ref.invalidate(playlistItemsProvider(playlist.id));
  }
}
