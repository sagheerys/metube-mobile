import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../shared/error_text.dart';

/// Converts the core's platform into its presentation type, since mt_ui
/// does not know mt_core.
MTPlatformKind platformKindOf(MediaPlatform platform) => switch (platform) {
  MediaPlatform.youtube => MTPlatformKind.youtube,
  MediaPlatform.tiktok => MTPlatformKind.tiktok,
  MediaPlatform.instagram => MTPlatformKind.instagram,
  MediaPlatform.soundcloud => MTPlatformKind.soundcloud,
  MediaPlatform.x => MTPlatformKind.x,
  MediaPlatform.facebook => MTPlatformKind.facebook,
  MediaPlatform.vimeo => MTPlatformKind.vimeo,
  MediaPlatform.twitch => MTPlatformKind.twitch,
  MediaPlatform.reddit => MTPlatformKind.reddit,
  MediaPlatform.dailymotion => MTPlatformKind.dailymotion,
  MediaPlatform.other => MTPlatformKind.other,
};

/// The add dialog plus automatic routing: a playlist goes to `/batch`, a
/// single link goes straight to the engine (rule 2).
Future<void> openAddSheet(
  BuildContext context,
  WidgetRef ref, {
  String? initialUrl,
}) async {
  final l10n = context.mtl;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    // The router and the messenger are captured **before** the sheet opens:
    // using them through the sheet's context after `Navigator.pop` queries
    // a deactivated element.
    builder: (sheetContext) => _AddSheet(
      initialUrl: initialUrl,
      l10n: l10n,
      router: GoRouter.of(context),
      messenger: ScaffoldMessenger.of(context),
    ),
  );
}

class _AddSheet extends ConsumerStatefulWidget {
  const _AddSheet({
    required this.initialUrl,
    required this.l10n,
    required this.router,
    required this.messenger,
  });

  final String? initialUrl;
  final MTLocalizations l10n;

  /// Captured from the hosting screen's context, so they stay valid after
  /// the sheet closes.
  final GoRouter router;
  final ScaffoldMessengerState messenger;

  @override
  ConsumerState<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends ConsumerState<_AddSheet> {
  /// **The sheet owns its controller and disposes it itself.** Disposing it
  /// in `openAddSheet` after `await showModalBottomSheet` happened **during
  /// the closing animation** while the field was still being rebuilt,
  /// giving "TextEditingController used after being disposed" and then a
  /// red screen (`_dependents.isEmpty`). `dispose` here only runs once the
  /// route is genuinely gone.
  late final TextEditingController _controller = TextEditingController(
    text: UrlKit.extractUrl(widget.initialUrl ?? ''),
  );
  late String _quality = ref.read(settingsProvider).quality.wire;
  late String _url = _controller.text;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final platform = MediaPlatform.detect(_url);
    // The quality rule: numeric qualities are offered for YouTube only.
    final qualities = [
      MTQualityOption(value: 'best', label: l10n.qualityBest),
      if (platform.isYouTube) ...[
        MTQualityOption(value: '1080', label: l10n.quality1080),
        MTQualityOption(value: '720', label: l10n.quality720),
        MTQualityOption(value: '480', label: l10n.quality480),
      ],
      MTQualityOption(value: 'audio', label: l10n.audioOnly),
    ];
    if (!qualities.any((q) => q.value == _quality)) _quality = 'best';

    return MTUrlInputSheet(
      title: l10n.addUrl,
      urlHint: l10n.pasteUrlHint,
      controller: _controller,
      onUrlChanged: (value) => setState(() => _url = value),
      platform: platformKindOf(platform),
      platformLabel: platform == MediaPlatform.other ? null : platform.label,
      qualities: qualities,
      selectedQuality: _quality,
      onQualitySelected: (value) => setState(() => _quality = value),
      startLabel: l10n.startDownload,
      onStart: () => unawaited(_submit()),
    );
  }

  Future<void> _submit() async {
    final l10n = widget.l10n;
    final input = UrlKit.extractUrl(_controller.text);
    if (!input.startsWith('http')) {
      showMTSnack(context, l10n.invalidUrl, type: MTSnackType.error);
      return;
    }
    Navigator.pop(context);

    // **The decision is made on the final URL, not the entered one** (field
    // report 2026-09-08): `on.soundcloud.com/…` is an album with no
    // `/sets/`, so it counted as a single clip and the server expanded it
    // into twenty with no selection screen. For links that are not short,
    // `needsResolution` returns false immediately, so there is no delay at
    // all.
    final url = await ref
        .read(shortLinkResolverProvider)
        .resolveForRouting(input);
    if (!mounted) return;

    // A playlist URL opens the batch screen.
    if (PlaylistDetector.isPlaylist(url)) {
      widget.router.push('/batch', extra: url);
      return;
    }
    final engine = ref.read(downloadEngineProvider);
    if (engine == null) {
      showMTSnackOn(
        widget.messenger,
        l10n.noServerTitle,
        type: MTSnackType.error,
      );
      return;
    }
    engine.submit(url, Quality.fromWire(_quality));
    showMTSnackOn(
      widget.messenger,
      l10n.downloadStarted,
      type: MTSnackType.success,
    );
  }
}

/// The error text for a failed task, used by the cards and the sheets.
String taskErrorText(MTLocalizations l10n, DownloadTask task) =>
    task.error == null ? l10n.failed : errorText(l10n, task.error!);
