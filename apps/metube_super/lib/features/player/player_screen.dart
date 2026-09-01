import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../di.dart';
import '../library/library_actions.dart';
import '../library/library_models.dart';
import '../library/library_providers.dart';
import 'playback_providers.dart';

/// مشغل الفيديو في Super (ر-4): يغذّي `MTVideoScreen` بأفعال التطبيق —
/// إتاحة دون اتصال، متابعة صوتاً (م-23)، مشاركة، وفتح الرابط الأصلي.
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
    final session = ref.watch(videoSessionProvider);
    return MTVideoScreen(
      session: session,
      artwork: artworkBuilderFor(ref),
      playlistName: request.playlistName,
      subtitleBuilder: _subtitle,
      actions: _actions(session),
      onContinueAsAudio: (item, position) => _continueAsAudio(item, position),
    );
  }

  String _subtitle(BuildContext context, PlaylistItem item) => [
        MediaPlatform.detect(item.canonicalUrl).label,
        if (item.uploader != null) item.uploader!,
      ].join(' · ');

  List<MTPlayerAction> _actions(MTVideoSession session) {
    final l10n = context.mtl;
    final item = session.current;
    if (item == null) return const [];
    return [
      MTPlayerAction(
        icon: Icons.download_rounded,
        label: item.hasLocal ? l10n.availabilityOffline : l10n.makeOffline,
        highlighted: item.hasLocal,
        onTap: item.hasLocal ? () {} : () => _makeOffline(item),
      ),
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
      MTPlayerAction(
        icon: Icons.open_in_new_rounded,
        label: l10n.openOriginalLink,
        onTap: () => launchUrl(Uri.parse(item.canonicalUrl),
            mode: LaunchMode.externalApplication),
      ),
    ];
  }

  /// العنصر المقابل في المكتبة — الأفعال تحتاج بياناته الكاملة.
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
    if (mounted) showMTSnack(context, context.mtl.madeOffline);
  }

  Future<void> _share(PlaylistItem item) async {
    final match = _libraryItemOf(item);
    if (match == null) return;
    await ref.read(libraryActionsProvider).smartShare(match);
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
    final index = ordered.indexWhere((i) => i.canonicalUrl == item.canonicalUrl);
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
