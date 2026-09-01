import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../library/library_actions.dart';
import '../library/library_models.dart';
import '../library/library_providers.dart';
import 'playback_providers.dart';

/// مشغل الريلز في Super (م-35) — يبني مسار القِصار من الطلب نفسه،
/// ويصل الأفعال (مفضلة/تحميل/لقائمة/مشاركة) بمنطق التطبيق.
class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final request = ref.watch(playbackRequestProvider);
    if (request == null) {
      return Scaffold(
        appBar: AppBar(),
        body: MTEmptyState(
          icon: Icons.bolt_rounded,
          title: l10n.shortsFilter,
          message: l10n.noPlayableSource,
        ),
      );
    }

    final lane = ShortsLane.from(request.items);
    final startUrl = request.items[request.startIndex].canonicalUrl;
    final laneIndex = lane.laneIndexOf(startUrl);
    if (lane.isEmpty || laneIndex < 0) {
      return Scaffold(
        appBar: AppBar(),
        body: MTEmptyState(
          icon: Icons.bolt_rounded,
          title: l10n.shortsFilter,
          message: l10n.noResultsMessage,
        ),
      );
    }

    return MTReelsPlayer(
      lane: lane,
      resolver: ref.watch(playbackResolverProvider),
      startIndex: laneIndex,
      subtitleBuilder: (context, item) => [
        MediaPlatform.detect(item.canonicalUrl).label,
        if (item.uploader != null) item.uploader!,
        if (item.hasLocal) l10n.availabilityOffline,
      ].join(' · '),
      isFavorite: (item) => _libraryItemOf(item)?.favorite ?? false,
      onToggleFavorite: (item) =>
          ref.read(libraryActionsProvider).toggleFavorite(item.canonicalUrl),
      actionsBuilder: (item) => [
        if (!item.hasLocal)
          // عمود الأفعال ضيّق ⇒ عناوين قصيرة (مرجع الريلز).
          MTPlayerAction(
            icon: Icons.download_rounded,
            label: l10n.download,
            onTap: () => _makeOffline(item),
          ),
        MTPlayerAction(
          icon: Icons.share_rounded,
          label: l10n.share,
          onTap: () => _share(item),
        ),
      ],
      // لا يُعرض الزر أصلاً إن كانت القائمة المعروضة كلها قِصار.
      onContinueRest: lane.nextNonShortIndex(request.items) == null
          ? null
          : () => _continueRest(request, lane),
    );
  }

  LibraryItem? _libraryItemOf(PlaylistItem item) {
    final items = ref.read(visibleLibraryProvider).value ?? const [];
    for (final candidate in items) {
      if (candidate.canonicalUrl == item.canonicalUrl) return candidate;
    }
    return null;
  }

  Future<void> _makeOffline(PlaylistItem item) async {
    final match = _libraryItemOf(item);
    if (match == null) return;
    await ref.read(libraryActionsProvider).makeOffline(match);
  }

  Future<void> _share(PlaylistItem item) async {
    final match = _libraryItemOf(item);
    if (match == null) return;
    await ref.read(libraryActionsProvider).smartShare(match);
  }

  /// «متابعة بقية القائمة»: أول عنصر غير قصير يُفتح في مشغله الصحيح.
  Future<void> _continueRest(PlaybackRequest request, ShortsLane lane) async {
    final index = lane.nextNonShortIndex(request.items);
    if (index == null) return context.pop();
    final next = request.items[index];
    if (next.isAudio) {
      await ref
          .read(audioHandlerProvider)
          .playItems(request.items, startIndex: index);
      if (mounted) context.pop();
      return;
    }
    ref.read(playbackRequestProvider.notifier).state = PlaybackRequest(
      items: request.items,
      startIndex: index,
      playlistId: request.playlistId,
      playlistName: request.playlistName,
    );
    if (mounted) context.pushReplacement('/player');
  }
}
