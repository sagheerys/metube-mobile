import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import '../wahaj/mt_progress.dart';
import 'mt_route_motion.dart';

/// Hands a file to the system share menu with a line on screen saying so.
///
/// **Why it is needed**: Android's share plugin copies the whole file before
/// the menu opens, and does it on the thread that also draws the app. With
/// a clip of a gigabyte the app stood still for seconds with nothing to
/// explain it, and read as frozen. The notice is drawn **before** the copy
/// starts, so even if its spinner stops while the copy runs, the words stay.
///
/// It goes away as soon as the menu covers the app (the app stops being the
/// active window), or when [send] returns, whichever is first.
Future<void> mtShareWithNotice(
  BuildContext context,
  Future<void> Function() send,
) async {
  final navigator = Navigator.of(context, rootNavigator: true);
  var open = true;
  void close() {
    if (!open) return;
    open = false;
    if (navigator.mounted) navigator.pop();
  }

  unawaited(
    showMTDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PopScope(canPop: false, child: MTShareOpening()),
    ).whenComplete(() => open = false),
  );
  // Drawn first: the copy that follows can hold the drawing thread. Never
  // waited on for long, so a frame that does not come cannot hold the share.
  await WidgetsBinding.instance.endOfFrame.timeout(
    const Duration(milliseconds: 250),
    onTimeout: () {},
  );
  final life = AppLifecycleListener(onInactive: close, onHide: close);
  try {
    await send();
  } finally {
    life.dispose();
    close();
  }
}

/// The notice itself: a spinner, what is happening, and why it can take a
/// moment. Shared by the dialog above and the share sheet's last phase.
class MTShareOpening extends StatelessWidget {
  const MTShareOpening({super.key, this.inSheet = false});

  /// Drawn inside a sheet that already has its own surface.
  final bool inSheet;

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final body = Row(
      children: [
        const MTSpinner(),
        const SizedBox(width: MTSpace.lg),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.shareOpening, style: text.titleMedium),
              const SizedBox(height: MTSpace.xs),
              Text(
                l.shareOpeningHint,
                style: text.bodySmall!.copyWith(color: p.ink2),
              ),
            ],
          ),
        ),
      ],
    );
    if (inSheet) return body;
    return Dialog(
      child: Padding(padding: const EdgeInsets.all(MTSpace.xl), child: body),
    );
  }
}
