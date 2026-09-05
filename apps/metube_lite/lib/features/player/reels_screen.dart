import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../downloads_library/library_actions.dart';
import '../downloads_library/library_providers.dart';
import '../downloads_library/local_item.dart';
import '../downloads_library/widgets/item_details_sheet.dart';
import '../shared/add_to_sheet.dart';
import '../shared/membership.dart';
import 'playback_providers.dart';

/// مشغل الريلز في Lite (م-35) — نفس مسار القِصار المصفّى، وأفعاله
/// المفضلة والمشاركة (لا زر تحميل: العنصر محلي أصلاً).
class ReelsScreen extends ConsumerStatefulWidget {
  const ReelsScreen({super.key});

  @override
  ConsumerState<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends ConsumerState<ReelsScreen> {
  /// **يُلتقط مرة واحدة وهذه الشاشة حية** (العطل الميداني 2026-09-03).
  /// المشغل الابن ينادي [_setLive] من `dispose()` الخاص به، والشجرة
  /// وقتها **مُبطلة**: `ref.read` حينئذٍ يرمي، والرمية كانت تُسقط بقية
  /// `dispose()` فيبقى مقطع يعمل بلا مالك.
  late final MTAudioHandler _audio = ref.read(audioHandlerProvider);

  /// آخر «موقِف» سلّمناه للمشغل الخلفي — لتمييز تسجيلنا عن تسجيل غيرنا.
  Future<void> Function()? _pauser;

  /// **لا نمسح تسجيل مالك آخر:** شاشة الفيديو تسجّل نفسها أيضاً، وموتنا
  /// بعد ولادتها كان يمحو تسجيلها فيعزف مصدران معاً.
  void _setLive(Future<void> Function()? pauser) {
    if (pauser == null) {
      if (_audio.onTakeVideoFocus == _pauser) _audio.onTakeVideoFocus = null;
      _pauser = null;
      return;
    }
    _pauser = pauser;
    _audio.onTakeVideoFocus = pauser;
  }

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

    // **يُقرأ في `build` لا داخل `subtitleBuilder`**: البنّاء يُنفَّذ
    // أثناء بناء ودجت **ابن**، و`ref.watch` هناك خارج نطاقه المسموح.
    final membership =
        ref.watch(membershipIndexProvider).valueOrNull ?? const {};

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
      onTakeAudioFocus: _audio.pause,
      // ع-4: ما دام الريل حياً، تشغيل الصوت من الإشعار يُسكته أولاً.
      onLive: _setLive,
      subtitleBuilder: (context, item) => [
        platformOfKey(item.canonicalUrl).label,
        // **الانتماء تحت العنوان** (بلاغ المالك 2026-09-04): في أي
        // قائمة — كانت المعلومة في المخزن ولا تظهر في أي مشغل.
        ?membership[item.canonicalUrl]?.line(l10n),
      ].join(' · '),
      isFavorite: (item) => _libraryItemOf(item)?.favorite ?? false,
      // **لا قلب في العمود** (بلاغ المالك 2026-09-04): زر «أضف إلى…»
      // أدناه يغطي المفضلة والقائمة معاً. الضغطة المزدوجة على المقطع
      // تبقى اختصار المفضلة (م-36) عبر [onDoubleTapFavorite].
      onDoubleTapFavorite: (item) =>
          ref.read(libraryActionsProvider).toggleFavorite(item.canonicalUrl),
      actionsBuilder: (item) {
        final match = _libraryItemOf(item);
        return [
          MTPlayerAction(
            icon: Icons.info_outline_rounded,
            label: l10n.details,
            onTap: () {
              if (match != null) showItemDetailsSheet(context, match);
            },
          ),
          MTPlayerAction(
            icon: Icons.playlist_add_rounded,
            label: l10n.addTo,
            onTap: () {
              if (match != null) showAddToSheet(context, ref, match);
            },
          ),
          MTPlayerAction(
            icon: Icons.share_rounded,
            label: l10n.share,
            onTap: () => _share(item),
          ),
        ];
      },
      // لا يُعرض الزر أصلاً إن كانت القائمة المعروضة كلها قِصار.
      onContinueRest: lane.nextNonShortIndex(request.items) == null
          ? null
          : () => _continueRest(request, lane),
    );
  }

  LocalItem? _libraryItemOf(PlaylistItem item) {
    final items = ref.read(localMediaProvider).valueOrNull ?? const [];
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
