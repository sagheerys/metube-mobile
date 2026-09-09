import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import 'add_flow.dart';

/// The quality name as the user sees it: what was **actually applied**
/// rather than what was chosen.
String qualityLabel(MTLocalizations l10n, Quality quality) => switch (quality) {
  Quality.best => l10n.qualityBest,
  Quality.q1080 => l10n.quality1080,
  Quality.q720 => l10n.quality720,
  Quality.q480 => l10n.quality480,
  Quality.audio => l10n.audioOnly,
};

/// **Quick download**: the link downloads immediately at the default
/// quality with no sheet.
///
/// Three deliberate decisions:
/// 1. **Playlists are never downloaded silently**, whatever the setting. A
/// playlist URL opens the batch screen so the user decides; 200 clips do
/// not start on a blind tap.
/// 2. **The quality shown is the quality applied**: `Quality.applyRule`
/// forces numeric qualities to `best` outside YouTube (a yt-dlp
/// constraint), so showing "1080" for a TikTok link lies to the user. We
/// show exactly what went to the server.
/// 3. **An undo, not a confirmation**: a confirmation dialog defeats the
/// meaning of "quick". Instead there is an action in the snack bar that
/// cancels the task and opens the sheet with the same URL.
///
/// **The setting is gated here rather than at the call site** (field
/// report 2026-09-04: "quick download is always on even though I turned it
/// off"). The condition used to be written into the share path alone,
/// while the floating add button and the launcher shortcut downloaded
/// immediately without asking, so the setting looked to have no effect.
/// Gating inside the function makes forgetting it impossible.
///
/// [explicit] is for an unambiguous deliberate action, the "download now"
/// button in the clipboard bar with "choose options" beside it, and that
/// works whatever the setting says.
///
/// Returns `false` when it cannot proceed (setting off, a playlist, no
/// server), and the caller takes over with the sheet.
bool startQuickDownload(
  BuildContext context,
  WidgetRef ref,
  String url, {
  bool announce = true,
  bool explicit = false,
}) {
  if (PlaylistDetector.isPlaylist(url)) return false;
  if (!explicit && !ref.read(settingsProvider).quickDownload) return false;
  final engine = ref.read(downloadEngineProvider);
  if (engine == null) return false;

  final l10n = context.mtl;
  final messenger = ScaffoldMessenger.of(context);
  final chosen = ref.read(settingsProvider).quality;
  final effective = chosen.applyRule(url);
  final task = engine.submit(url, chosen);
  if (!announce) return true;

  showMTSnackOn(
    messenger,
    l10n.downloadStartedQuality(qualityLabel(l10n, effective)),
    type: MTSnackType.success,
    themeContext: context,
    actionLabel: l10n.changeQuality,
    onAction: () {
      engine.cancel(task.id);
      if (context.mounted) openAddSheet(context, ref, initialUrl: url);
    },
  );
  return true;
}
