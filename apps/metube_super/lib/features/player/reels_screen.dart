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
import '../library/widgets/item_details_sheet.dart';
import '../shared/add_to_sheet.dart';
import '../shared/membership.dart';
import 'playback_providers.dart';

/// مشغل الريلز في Super (م-35) — يبني مسار القِصار من الطلب نفسه،
/// ويصل الأفعال (مفضلة/تحميل/لقائمة/مشاركة) بمنطق التطبيق.
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

    // تُقرأ هنا لا داخل المُنشئات: `ref.watch` مسموح في `build` وحده،
    // وهي التي تُعيد بناء الأفعال حين تتغير المكتبة أو يتقدم السحب.
    final library = ref.watch(visibleLibraryProvider).value ?? const [];
    final byUrl = {for (final item in library) item.canonicalUrl: item};
    final pulls = ref.watch(offlinePullProgressProvider);
    // **يُقرأ في `build` لا داخل `subtitleBuilder`**: البنّاء يُنفَّذ
    // أثناء بناء ودجت **ابن**، و`ref.watch` هناك خارج نطاقه المسموح.
    final membership =
        ref.watch(membershipIndexProvider).value ?? const {};

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
      onTakeAudioFocus: _audio.pause,
      // ع-4: ما دام الريل حياً، تشغيل الصوت من الإشعار يُسكته أولاً.
      onLive: _setLive,
      subtitleBuilder: (context, item) => [
        MediaPlatform.detect(item.canonicalUrl).label,
        if (item.uploader != null) item.uploader!,
        // من المكتبة الحيّة: `item.hasLocal` لقطة قديمة لا تتحدث.
        if (byUrl[item.canonicalUrl]?.isOffline ?? item.hasLocal)
          l10n.availabilityOffline,
        // **الانتماء تحت العنوان** (بلاغ المالك 2026-09-04): في أي وسم
        // وأي قائمة — كانت المعلومة في المخزن ولا تظهر في أي مشغل.
        ?membership[item.canonicalUrl]?.line(l10n),
      ].join(' · '),
      isFavorite: (item) => byUrl[item.canonicalUrl]?.favorite ?? false,
      // **لا قلب في العمود** (بلاغ المالك 2026-09-04): زر «أضف إلى…»
      // أدناه يغطي المفضلة والوسم والقائمة معاً. الضغطة المزدوجة على
      // المقطع تبقى اختصار المفضلة (م-36) عبر [onDoubleTapFavorite].
      onDoubleTapFavorite: (item) =>
          ref.read(libraryActionsProvider).toggleFavorite(item.canonicalUrl),
      // **الحالة تُقرأ من المكتبة الحيّة لا من عنصر التشغيل** (بلاغ
      // المالك 2026-09-02): `PlaylistItem` لقطة وقت فتح المشغل، فبقي
      // زر التنزيل كما هو بعد اكتمال الإتاحة. و`pulls` يعرض النسبة
      // فلا يبدو الزر ميتاً أثناء السحب.
      actionsBuilder: (item) {
        final match = byUrl[item.canonicalUrl];
        final offline = match?.isOffline ?? item.hasLocal;
        final progress = pulls[item.canonicalUrl];
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
          if (progress != null)
            MTPlayerAction(
              icon: Icons.downloading_rounded,
              label: '${(progress * 100).round()}٪',
              onTap: () {},
            )
          else if (!offline)
            // نفس تسمية المشغل العرضي: كان «تنزيل» هنا و«إتاحة دون
            // اتصال» هناك لنفس الفعل بالضبط.
            MTPlayerAction(
              icon: Icons.download_rounded,
              label: l10n.saveToDevice,
              onTap: () => _makeOffline(item),
            )
          else
            MTPlayerAction(
              icon: Icons.offline_pin_rounded,
              label: l10n.savedOnDevice,
              highlighted: true,
              onTap: () {},
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
    final l10n = context.mtl;
    try {
      await ref.read(libraryActionsProvider).makeOffline(match);
      if (mounted) {
        showMTSnack(context, l10n.availableOfflineNow,
            type: MTSnackType.success);
      }
    } on Object {
      if (mounted) {
        showMTSnack(context, l10n.failed, type: MTSnackType.error);
      }
    }
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
