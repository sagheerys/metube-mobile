import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../../di.dart';
import '../../shared/error_report.dart';

/// The active server's state. null means not configured. Otherwise a
/// classified state: **"rejects your credentials" is not "could not
/// reach"** — the first is fixed by the two fields beneath this card, and
/// the second is not.
final serverStatusProvider = FutureProvider<MTEndpointStatus?>((ref) async {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  try {
    await api.testConnection();
    clearErrorSignature('server-status');
    return MTEndpointStatus.ok;
  } on MTApiException catch (e) {
    unawaited(logErrorOnce(ref.read(loggerProvider), 'server-status', e));
    return switch (e) {
      AuthFailureException() => MTEndpointStatus.unauthorized,
      // The address is alive but is not MeTube: an address mistake, not a
      // network one.
      NotMeTubeServerException() ||
      NoApiException() => MTEndpointStatus.notMeTube,
      _ => MTEndpointStatus.unreachable,
    };
  }
});

/// **What the server holds and what it is running** (§2.6), or null when
/// there is nothing to say.
///
/// Read **once per visit to this screen** and never polled: the counts come
/// from the `/history` the app fetches anyway, the version is a single
/// extra request, and the newest MeTube release is one call to GitHub that
/// Riverpod caches for the session. Whoever presses refresh gets a fresh
/// answer; nobody else pays for one.
final serverDetailsProvider = FutureProvider<ServerDetails?>((ref) async {
  final api = ref.watch(apiClientProvider);
  if (api == null) return null;
  // The status above already said whether the server answers at all; there
  // is nothing to show beside "unreachable".
  final status = await ref.watch(serverStatusProvider.future);
  if (status != MTEndpointStatus.ok) return null;
  final history = await api.fetchHistory();
  final version = await api.fetchVersion();
  // **Last, and only if it can be compared.** Asking GitHub what the newest
  // MeTube is, for a server that will not say what it runs, is a request
  // whose answer nobody could use.
  final latest = version != null && version.isKnown
      ? await const MeTubeReleaseChecker(fetch: ioHttpGetString).latestTag()
      : null;
  return ServerDetails(
    // Failed items sit in `done` too; a file count that counts them is
    // wrong by exactly the number of things the user would least expect.
    files: history.done.where((item) => item.isCompleted).length,
    queued: history.active.length,
    version: version,
    latestRelease: latest,
  );
});

/// The line under the server's address: how much it holds, and what it is.
class ServerDetails {
  const ServerDetails({
    required this.files,
    required this.queued,
    this.version,
    this.latestRelease,
  });

  final int files;
  final int queued;
  final ServerVersion? version;

  /// The newest tag on `alexta69/metube`, when it was worth asking.
  final String? latestRelease;

  /// **Only ever true for two real dated versions**; `dev`, an old MeTube
  /// with no `/version`, and a fork numbering releases its own way all
  /// answer false. Saying "out of date" to someone whose server is fine is
  /// worse than saying nothing.
  bool get isOutdated =>
      latestRelease != null && (version?.isOlderThan(latestRelease!) ?? false);
}

/// The server status card, always espresso-dark (log §4).
class ServerStatusCard extends ConsumerWidget {
  const ServerStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final status = ref.watch(serverStatusProvider);
    final settings = ref.watch(settingsProvider);
    final p = MTThemeX.of(context).palette;

    final (icon, tint, label) = switch (status) {
      AsyncData(value: MTEndpointStatus.ok) => (
        Icons.cloud_done_rounded,
        p.ok,
        l10n.serverStatusConnected,
      ),
      // The card is **always dark** (log §4), and Lite's petrol accent is
      // not legible on it, so the distinction is made with the icon and the
      // text rather than with colour.
      AsyncData(value: MTEndpointStatus.unauthorized) => (
        Icons.lock_outline_rounded,
        MTPalette.serverCardInk,
        l10n.signInRequired,
      ),
      // "Not MeTube" is not an outage: the address is alive and answering,
      // and the cure is correcting the address rather than waiting for the
      // network.
      AsyncData(value: MTEndpointStatus.notMeTube) => (
        Icons.link_off_rounded,
        MTPalette.serverCardInk,
        l10n.errNotMeTube,
      ),
      AsyncData(value: MTEndpointStatus.unreachable) => (
        Icons.cloud_off_rounded,
        p.err,
        l10n.serverStatusOffline,
      ),
      AsyncData(value: null) => (
        Icons.cloud_outlined,
        MTPalette.serverCardInk,
        l10n.serverStatusUnconfigured,
      ),
      _ => (
        Icons.cloud_sync_rounded,
        MTPalette.serverCardInk,
        l10n.serverStatusChecking,
      ),
    };

    return Container(
      padding: const EdgeInsets.all(MTSpace.lg),
      decoration: BoxDecoration(
        color: MTPalette.serverCardBg,
        borderRadius: BorderRadius.circular(MTRadius.cardLg),
      ),
      child: Row(
        children: [
          Icon(icon, color: tint, size: 26),
          const SizedBox(width: MTSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: MTPalette.serverCardInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (settings.isConfigured)
                  Text(
                    settings.activeUrl!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: MTPalette.serverCardInk.withValues(alpha: 0.6),
                    ),
                  ),
                const _ServerDetailsLines(),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.refresh,
            onPressed: () {
              ref.invalidate(serverStatusProvider);
              ref.invalidate(serverDetailsProvider);
            },
            icon: Icon(
              Icons.refresh_rounded,
              color: MTPalette.serverCardInk.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// The two lines under the address: how much the server holds, and what it
/// is running.
///
/// **It shows nothing at all while it does not know** — no spinner, no
/// placeholder. The card's own state line already says whether the server
/// answers; a second "loading" under it would be noise on a screen that is
/// opened to read one address.
class _ServerDetailsLines extends ConsumerWidget {
  const _ServerDetailsLines();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final details = ref.watch(serverDetailsProvider).valueOrNull;
    if (details == null) return const SizedBox.shrink();
    final l10n = context.mtl;
    final text = Theme.of(context).textTheme.bodySmall!;
    final ink = MTPalette.serverCardInk;

    final counts = [
      l10n.serverFilesCount(details.files),
      if (details.queued > 0) l10n.serverQueueCount(details.queued),
    ].join(' · ');

    // `dev`, or a MeTube too old to have the endpoint: named as unknown
    // rather than passed over, so the absence is a fact and not a gap.
    final version = switch (details.version) {
      final ServerVersion v when v.isKnown => l10n.serverVersionLabel(
        v.version,
      ),
      _ => l10n.serverVersionUnknown,
    };

    return Padding(
      padding: const EdgeInsets.only(top: MTSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$counts · $version',
            style: text.copyWith(color: ink.withValues(alpha: 0.6)),
          ),
          if (details.isOutdated)
            Padding(
              padding: const EdgeInsets.only(top: MTSpace.xs),
              // **Full-strength ink and bold, not a colour.** There is no
              // "warning" token in the palette, and inventing one is a
              // design decision (§3, the owner's). Red would be wrong
              // anyway: a server a release behind is information, not a
              // fault, and the contrast against the muted line above is
              // what makes it read.
              child: Text(
                l10n.serverVersionOutdated(details.latestRelease!),
                style: text.copyWith(color: ink, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}
