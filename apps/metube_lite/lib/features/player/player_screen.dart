import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../di.dart';
import '../downloads_library/library_actions.dart';
import '../downloads_library/library_providers.dart';
import '../downloads_library/local_item.dart';
import '../playlists/playlist_dialogs.dart';
import 'playback_providers.dart';

/// مشغل الفيديو في Lite (ر-4): كل المصادر محلية، فالأفعال هي المتابعة
/// صوتاً (م-23) والمشاركة وفتح الرابط الأصلي — لا «إتاحة دون اتصال».
class PlayerScreen extends ConsumerStatefulWidget {
  const PlayerScreen({super.key});

  @override
  ConsumerState<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends ConsumerState<PlayerScreen> {
  PlaybackRequest? _request;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final request = ref.read(playbackRequestProvider);
    if (request == null || !mounted) return;
    setState(() => _request = request);
    await ref.read(videoSessionProvider).open(
          request.items,
          startIndex: request.startIndex,
          playlistId: request.playlistId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    // مراقبة قبل أي خروج مبكر: `videoSessionProvider` تلقائي التصريف،
    // فقراءته بلا مراقبة تصرّفه فوراً ولا يشتغل شيء.
    final session = ref.watch(videoSessionProvider);
    final request = _request;
    if (request == null) {
      return Scaffold(
        appBar: AppBar(),
        body: MTEmptyState(
          icon: Icons.play_disabled_rounded,
          title: l10n.videoPlayer,
          message: l10n.noPlayableSource,
        ),
      );
    }
    return MTVideoScreen(
      session: session,
      artwork: artworkBuilderFor(ref),
      playlistName: request.playlistName,
      subtitleBuilder: _subtitle,
      actions: _actions(session),
      onContinueAsAudio: (item, position) => _continueAsAudio(item, position),
      // **لا يُسأل مرتين** (بلاغ المالك 2026-09-02): من نقل المقطع
      // للصوت فعلاً ثم ضغط رجوع كان يُسأل عن مقطع يسمعه بالفعل.
      shouldOfferContinueAsAudio: _shouldOfferAudio,
      onSaveQueueAsPlaylist: () => _saveQueue(session.orderedItems),
      onShowPlaylist: request.playlistId == null
          ? null
          : () => context.push('/playlists/${request.playlistId}'),
    );
  }

  String _subtitle(BuildContext context, PlaylistItem item) =>
      platformOfKey(item.canonicalUrl).label;

  List<MTPlayerAction> _actions(MTVideoSession session) {
    final l10n = context.mtl;
    final item = session.current;
    if (item == null) return const [];
    return [
      MTPlayerAction(
        icon: Icons.headphones_rounded,
        label: l10n.continueAsAudio,
        onTap: () => _continueAsAudio(item, session.position, pop: true),
      ),
      MTPlayerAction(
        icon: Icons.share_rounded,
        label: l10n.share,
        onTap: () => _share(item),
      ),
      if (item.canonicalUrl.startsWith('http'))
        MTPlayerAction(
          icon: Icons.open_in_new_rounded,
          label: l10n.openOriginalLink,
          onTap: () => launchUrl(Uri.parse(item.canonicalUrl),
              mode: LaunchMode.externalApplication),
        ),
    ];
  }

  LocalItem? _libraryItemOf(PlaylistItem item) {
    final items = ref.read(localMediaProvider).value ?? const [];
    for (final candidate in items) {
      if (candidate.key == item.canonicalUrl) return candidate;
    }
    return null;
  }

  Future<void> _saveQueue(List<PlaylistItem> items) async {
    final name = await promptPlaylistName(context);
    if (name == null || !mounted) return;
    if (await saveQueueAsPlaylist(ref, name, items) && mounted) {
      showMTSnack(context, context.mtl.queueSavedAsPlaylist,
          type: MTSnackType.success);
    }
  }

  Future<void> _share(PlaylistItem item) async {
    final match = _libraryItemOf(item);
    if (match == null) return;
    await ref.read(libraryActionsProvider).share([match]);
  }

  /// السؤال يستحق أن يُطرح فقط إن كان هناك ما يُنقل: مقطع حالي، ولم
  /// يكن مشغل الصوت يشتغله أصلاً.
  bool _shouldOfferAudio() {
    final current = ref.read(videoSessionProvider).current;
    if (current == null) return false;
    final handler = ref.read(audioHandlerProvider);
    final playingSame =
        handler.currentItem?.canonicalUrl == current.canonicalUrl;
    return !(playingSame && handler.playbackState.value.playing);
  }

  /// م-23: متابعة نفس العنصر صوتاً بالخلفية من نفس الثانية.
  Future<void> _continueAsAudio(
    PlaylistItem item,
    Duration position, {
    bool pop = false,
  }) async {
    final session = ref.read(videoSessionProvider);
    final handler = ref.read(audioHandlerProvider);
    final ordered = session.orderedItems;
    final index =
        ordered.indexWhere((i) => i.canonicalUrl == item.canonicalUrl);
    // **قبل** بدء الصوت: الفيديو كان يستمر طوال تحميل المصدر الصوتي
    // فيُسمع المقطع مرتين (خلل مصطاد — يطول على شبكة بطيئة).
    await session.pause();
    await ref
        .read(playbackPositionsProvider)
        .save(item.canonicalUrl, position, duration: session.duration);
    await handler.playItems(
      ordered,
      startIndex: index < 0 ? 0 : index,
      playlistId: session.playlistId,
    );
    if (pop && mounted) context.pop();
  }
}
