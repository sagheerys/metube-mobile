import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../downloads_library/artwork_view.dart';
import '../home/add_flow.dart' show platformKindOf;
import '../player/playback_providers.dart';
import 'playlist_dialogs.dart';
import 'playlists_providers.dart';

/// تفاصيل قائمة محفوظة (ر-7 خطوة 2): تشغيل الكل / عشوائي / زر السماعات
/// · سحب لإعادة الترتيب · حذف عنصر **مع تراجع** · مؤشر الحالي.
class PlaylistDetailsScreen extends ConsumerWidget {
  const PlaylistDetailsScreen({super.key, required this.playlistId});

  final String playlistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final playlists = ref.watch(playlistsProvider).value ?? const [];
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
                        playlistId: playlistId, view: view),
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
      // **المفقود لا يدخل الطابور**: مصدره يفشل فيقفز المشغل للتالي،
      // فتبدو النقرة كأنها شغّلت مقطعاً غيره (بلاغ المالك 2026-09-04).
      final visual = await ref.read(playlistPlayerProvider).play(
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
          MTSpace.pagePad, MTSpace.sm, MTSpace.pagePad, MTSpace.md),
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
          // زر السماعات: القائمة كلها صوتاً بالخلفية ولو فيها فيديو.
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
    // **المؤشر كان يعلق على المقطع الأول** (لقطة المالك 2026-09-02،
    // العطل ط-8): `ref.watch(audioHandlerProvider)` يراقب مزوداً مثبتاً
    // بـ override **لا يبثّ أبداً**، و`currentItem` getter فوق حالة
    // متغيرة — أي قراءة لمرة واحدة متنكرة في هيئة مراقبة. الصواب
    // الموجود في الحزمة نفسها: بثّ `handler.mediaItem` (ومعرفه هو
    // canonicalUrl).
    // **الحالي شيء، والعازف شيء آخر**: مؤشر التوازن كان يرقص على مقطع
    // موقوف مؤقتاً لأن الشاشة لا تعرف إلا «أيّ عنصر هو الحالي»
    // (بلاغ المالك 2026-09-04). التياران معاً يفصلان الحالتين.
    final handler = ref.read(audioHandlerProvider);
    return StreamBuilder<String?>(
      stream: handler.currentKey,
      builder: (context, keySnapshot) => StreamBuilder<bool>(
        stream: handler.playingStream,
        initialData: true,
        builder: (context, playingSnapshot) => _list(
          context,
          ref,
          keySnapshot.data,
          playingSnapshot.data ?? true,
        ),
      ),
    );
  }

  Widget _list(BuildContext context, WidgetRef ref, String? playingKey,
      bool isPlaying) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(
          MTSpace.pagePad, 0, MTSpace.pagePad, 140),
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
            // المفقود يقول ذلك بنفسه بدل أن يبدو صالحاً ثم لا يعمل.
            subtitle: missing ? context.mtl.itemUnavailable : item.uploader,
            playing: !missing && item.canonicalUrl == playingKey,
            paused: !isPlaying,
            thumbnail: item.artworkUrl == null
                ? null
                : artworkFor(item.artworkUrl),
            platform: platformKindOf(platformOfKey(item.canonicalUrl)),
            compact: true,
            onTap: () => missing
                ? showMTSnack(context, context.mtl.itemUnavailable,
                    type: MTSnackType.error)
                : _playFrom(context, ref, item),
          ),
        );
      },
    );
  }

  /// **الفهرس يُحسب داخل الصالح لا داخل المعروض**: قائمة فيها مداخل
  /// ميتة كانت تُشغّل العنصر الخطأ لأن الفهرسين اختلفا.
  Future<void> _playFrom(
      BuildContext context, WidgetRef ref, PlaylistItem item) async {
    final playlist =
        (ref.read(playlistsProvider).value ?? const <SavedPlaylist>[])
            .where((p) => p.id == playlistId)
            .firstOrNull;
    final playable = view.playable;
    final index =
        playable.indexWhere((i) => i.canonicalUrl == item.canonicalUrl);
    if (index < 0) return;
    final visual = await ref.read(playlistPlayerProvider).play(
          playable,
          startIndex: index,
          playlistId: playlistId,
          playlistName: playlist?.name,
        );
    if (visual && context.mounted) context.push('/player');
  }

  /// حذف عنصر مع **تراجع** (ر-7): الإزالة تُعاد كما كانت بنفس موضعها.
  void _removeWithUndo(
      BuildContext context, WidgetRef ref, PlaylistItem item, int index) {
    final l10n = context.mtl;
    final store = ref.read(playlistsStoreProvider);
    final entry = PlaylistEntry(
      canonicalUrl: item.canonicalUrl,
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
        await store.reorderItem(playlistId,
            (await store.byId(playlistId))!.items.length - 1, index);
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
