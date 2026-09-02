import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../downloads_library/library_actions.dart';
import '../downloads_library/library_providers.dart';
import '../downloads_library/local_item.dart';
import 'playback_providers.dart';

/// مشغل الريلز في Lite (م-35) — نفس مسار القِصار المصفّى، وأفعاله
/// المفضلة والمشاركة (لا زر تحميل: العنصر محلي أصلاً).
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
    final startKey = request.items[request.startIndex].canonicalUrl;
    final laneIndex = lane.laneIndexOf(startKey);
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
      onTakeAudioFocus: ref.read(audioHandlerProvider).pause,
      // ع-4: ما دام الريل حياً، تشغيل الصوت من الإشعار يُسكته أولاً.
      onLive: (pauser) =>
          ref.read(audioHandlerProvider).onTakeVideoFocus = pauser,
      subtitleBuilder: (context, item) =>
          platformOfKey(item.canonicalUrl).label,
      isFavorite: (item) => _libraryItemOf(item)?.favorite ?? false,
      onToggleFavorite: (item) =>
          ref.read(libraryActionsProvider).toggleFavorite(item.canonicalUrl),
      actionsBuilder: (item) => [
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

  LocalItem? _libraryItemOf(PlaylistItem item) {
    final items = ref.read(localMediaProvider).value ?? const [];
    for (final candidate in items) {
      if (candidate.key == item.canonicalUrl) return candidate;
    }
    return null;
  }

  Future<void> _share(PlaylistItem item) async {
    final match = _libraryItemOf(item);
    if (match == null) return;
    await ref.read(libraryActionsProvider).share([match]);
  }

  /// «متابعة بقية القائمة»: أول عنصر غير قصير يُفتح في مشغله الصحيح.
  Future<void> _continueRest(PlaybackRequest request, ShortsLane lane) async {
    final index = lane.nextNonShortIndex(request.items);
    if (index == null) return context.pop();
    final next = request.items[index];
    if (next.isAudio) {
      // نغلق الريلز **أولاً** فيُصرَّف متحكمه: تشغيل الصوت قبل الإغلاق
      // يترك الريل يعمل طوال تحميل المصدر — صوتان معاً.
      final handler = ref.read(audioHandlerProvider);
      context.pop();
      await handler.playItems(request.items, startIndex: index);
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
