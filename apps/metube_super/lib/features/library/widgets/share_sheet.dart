import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/library.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../shared/error_text.dart';
import '../library_actions.dart';
import '../device_pulls.dart';
import '../share_flow.dart';
import 'phone_pulls.dart';

bool _asking = false;
bool _sheetOpen = false;

/// Shares [item]: at once when the phone has a copy, otherwise after
/// pulling one, with a sheet that shows how far it has got.
///
/// A share already running is shown rather than started again, so a
/// second tap on any clip opens the same sheet.
Future<void> shareClip(
  BuildContext context,
  WidgetRef ref,
  LibraryItem item,
) async {
  final local = item.localPath;
  if (local != null) {
    final send = ref.read(shareSendProvider);
    return mtShareWithNotice(context, () => send(local));
  }
  // The app's own navigator, not [context]: shared from a clip's menu,
  // [context] is the clip's card, which the list may rebuild while the
  // question is open. The share used to stop there in silence, so a tap on
  // "download" showed nothing and was tapped again and again.
  final navigator = Navigator.of(context, rootNavigator: true);
  final flow = ref.read(shareFlowProvider.notifier);
  if (ref.read(shareFlowProvider) == null) {
    if (_asking) return;
    if (!ref.read(libraryActionsProvider).canPullNow) {
      throw const NetworkException(wifiOnlyRejection);
    }
    if (item.serverFilename == null) throw const UnsafeFilenameException();
    final size = item.sizeBytes;
    if (size != null && size >= shareConfirmBytes) {
      _asking = true;
      final go = await _confirmLarge(
        context,
        size,
      ).whenComplete(() => _asking = false);
      if (!go) return;
    }
    unawaited(flow.start(item));
  }
  if (_sheetOpen || !navigator.mounted) return;
  _sheetOpen = true;
  final l10n = navigator.context.mtl;
  final box = ProviderScope.containerOf(navigator.context, listen: false);
  unawaited(
    showMTSheet<void>(
      context: navigator.context,
      useRootNavigator: true,
      builder: (_) => const ShareSheet(),
    ).whenComplete(() {
      _sheetOpen = false;
      // Closed by a tap outside while the copy goes on (field report
      // 2026-11-04): nothing else on screen said it was still running.
      if (box.read(shareFlowProvider)?.phase == SharePhase.pulling &&
          navigator.mounted) {
        showMTSnack(navigator.context, l10n.shareGoesOn);
      }
    }),
  );
}

Future<bool> _confirmLarge(BuildContext context, int size) {
  final l10n = context.mtl;
  return showMTConfirm(
    context,
    title: l10n.shareLargeTitle(mtFormatSize(size)),
    // Messaging apps refuse files over 2 GB, said before an hour of
    // downloading rather than after it.
    message: size >= shareMessagingBytes
        ? '${l10n.shareLargeBody}\n\n${l10n.shareMessagingLimit}'
        : l10n.shareLargeBody,
    confirmLabel: l10n.download,
    cancelLabel: l10n.cancel,
  );
}

/// How far the copy for a share has got, with a way out. Closing the sheet
/// does not stop the copy: the share menu still opens when it is done.
class ShareSheet extends ConsumerStatefulWidget {
  const ShareSheet({super.key});

  @override
  ConsumerState<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<ShareSheet> {
  late final ShareFlow _flow = ref.read(shareFlowProvider.notifier);

  @override
  void initState() {
    super.initState();
    _flow.watched = true;
  }

  @override
  void dispose() {
    _flow.sheetClosed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(shareFlowProvider, (_, next) {
      final route = ModalRoute.of(context);
      if (next != null || route == null || !route.isActive) return;
      // Removed even when another sheet has opened above it, or an empty
      // sheet was left behind once that one closed.
      route.isCurrent
          ? Navigator.of(context).pop()
          : Navigator.of(context).removeRoute(route);
    });
    final job = ref.watch(shareFlowProvider);
    if (job == null) return const SizedBox.shrink();
    if (job.phase == SharePhase.opening) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          MTSpace.xl,
          MTSpace.xl,
          MTSpace.xl,
          mtSheetBottomPad(context, MTSpace.xxl),
        ),
        child: const MTShareOpening(inSheet: true),
      );
    }
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MTSpace.xl,
        MTSpace.lg,
        MTSpace.xl,
        mtSheetBottomPad(context, MTSpace.xxl),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(switch (job.phase) {
            SharePhase.pulling => l10n.sharePreparing,
            SharePhase.ready => l10n.shareReady,
            SharePhase.opening => l10n.shareOpening,
            SharePhase.failed => l10n.failed,
          }, style: text.titleMedium),
          const SizedBox(height: MTSpace.xs),
          Text(
            job.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.bodySmall!.copyWith(color: p.ink2),
          ),
          const SizedBox(height: MTSpace.lg),
          ...switch (job.phase) {
            SharePhase.pulling => [
              PhonePullProgress(
                pull: ref.watch(
                  devicePullsProvider,
                )[DevicePull.keyOf(job.kind, job.url)],
              ),
              const SizedBox(height: MTSpace.sm),
              TextButton(onPressed: _flow.cancel, child: Text(l10n.cancel)),
            ],
            SharePhase.ready => [
              FilledButton.icon(
                onPressed: () => unawaited(_flow.sendReady()),
                icon: const MTIcon(MTIcons.share, size: 18),
                label: Text(l10n.share),
              ),
              TextButton(onPressed: _flow.cancel, child: Text(l10n.cancel)),
            ],
            SharePhase.opening => const <Widget>[],
            SharePhase.failed => [
              Text(
                errorText(l10n, job.error!),
                style: text.bodyMedium!.copyWith(color: p.err),
              ),
              const SizedBox(height: MTSpace.sm),
              TextButton(onPressed: _flow.dismiss, child: Text(l10n.done)),
            ],
          },
        ],
      ),
    );
  }
}
