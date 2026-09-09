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
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.refresh,
            onPressed: () => ref.invalidate(serverStatusProvider),
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
