import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../shared/error_text.dart';

/// تحويل منصة النواة إلى نوعها البصري (mt_ui لا يعرف mt_core).
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

/// حوار الإضافة (م-1) + التوجيه التلقائي (م-5): قائمة ⇒ `/batch`،
/// مفرد ⇒ إرسال للمحرك فوراً — ر-2.
Future<void> openAddSheet(
  BuildContext context,
  WidgetRef ref, {
  String? initialUrl,
}) async {
  final l10n = context.mtl;
  final controller =
      TextEditingController(text: UrlKit.extractUrl(initialUrl ?? ''));

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => _AddSheet(controller: controller, l10n: l10n),
  );
  controller.dispose();
}

class _AddSheet extends ConsumerStatefulWidget {
  const _AddSheet({required this.controller, required this.l10n});

  final TextEditingController controller;
  final MTLocalizations l10n;

  @override
  ConsumerState<_AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends ConsumerState<_AddSheet> {
  late String _quality = ref.read(settingsProvider).quality.wire;
  late String _url = widget.controller.text;

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final platform = MediaPlatform.detect(_url);
    // قاعدة الجودة (م-1): الرقمية تُعرض ليوتيوب فقط.
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
      controller: widget.controller,
      onUrlChanged: (value) => setState(() => _url = value),
      platform: platformKindOf(platform),
      platformLabel: platform == MediaPlatform.other ? null : platform.label,
      qualities: qualities,
      selectedQuality: _quality,
      onQualitySelected: (value) => setState(() => _quality = value),
      startLabel: l10n.startDownload,
      onStart: _submit,
    );
  }

  void _submit() {
    final l10n = widget.l10n;
    final url = UrlKit.extractUrl(widget.controller.text);
    if (!url.startsWith('http')) {
      showMTSnack(context, l10n.invalidUrl, type: MTSnackType.error);
      return;
    }
    Navigator.pop(context);
    final router = GoRouter.of(context);
    final messengerContext = context;

    // م-5: رابط قائمة ⇒ شاشة الدفعي.
    if (PlaylistDetector.isPlaylist(url)) {
      router.push('/batch', extra: url);
      return;
    }
    final engine = ref.read(downloadEngineProvider);
    if (engine == null) {
      showMTSnack(messengerContext, l10n.noServerTitle,
          type: MTSnackType.error);
      return;
    }
    engine.submit(url, Quality.fromWire(_quality));
    showMTSnack(messengerContext, l10n.downloadStarted,
        type: MTSnackType.success);
  }
}

/// نص خطأ مهمة فاشلة — للاستخدام في البطاقات والأوراق.
String taskErrorText(MTLocalizations l10n, DownloadTask task) =>
    task.error == null ? l10n.failed : errorText(l10n, task.error!);
