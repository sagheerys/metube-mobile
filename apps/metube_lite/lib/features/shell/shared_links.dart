import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';

/// The most links one share sends. A share of a whole conversation or a
/// web page can carry hundreds, each a download on the server.
const int maxSharedLinks = 50;

/// Several links shared at once: asked about first, then sent together.
///
/// **Why asked** (security review 2026-11-05): a single link opens the add
/// sheet, but a share holding several sent every one of them to the server
/// at once, with nothing to stop it. Sharing a chat or a page by mistake
/// was enough to fill the server, and on this phone, its storage.
/// [capped] says the share held more than [maxSharedLinks], of which
/// [urls] are the first.
Future<void> submitSharedLinks(
  BuildContext context,
  WidgetRef ref,
  List<String> urls, {
  required bool capped,
  required void Function(String step) note,
}) async {
  final engine = ref.read(downloadEngineProvider);
  if (engine == null) return note('share dropped: no server');
  final l10n = context.mtl;
  final go = await showMTConfirm(
    context,
    title: l10n.sharedLinksTitle(urls.length),
    message: l10n.sharedLinksBody,
    confirmLabel: l10n.sharedLinksAdd,
    cancelLabel: l10n.cancel,
  );
  if (!go || !context.mounted) {
    return note('share of ${urls.length} links declined');
  }
  note('share of ${urls.length} links');
  final quality = ref.read(settingsProvider).quality;
  for (final url in urls) {
    if (PlaylistDetector.isPlaylist(url)) {
      GoRouter.of(context).push('/batch', extra: url);
    } else {
      engine.submit(url, quality, isBatchMember: true);
    }
  }
  showMTSnack(
    context,
    capped ? l10n.sharedLinksCapped(maxSharedLinks) : l10n.downloadStarted,
    type: capped ? MTSnackType.info : MTSnackType.success,
  );
}
