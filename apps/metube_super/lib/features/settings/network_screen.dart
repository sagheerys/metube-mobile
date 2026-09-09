import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import 'widgets/help_button.dart';
import 'widgets/server_status_card.dart';

/// The reachability state of every endpoint (live), probed in parallel
/// with a 4s timeout.
final endpointsStatusProvider = FutureProvider<Map<String, MTEndpointStatus>>((
  ref,
) async {
  final settings = ref.watch(settingsProvider);
  final resolver = ref.watch(endpointResolverProvider);
  if (settings.candidateUrls.isEmpty) return {};
  return resolver.probeAll(settings.candidateUrls);
});

/// Managing server endpoints: a local one plus ordered external ones, with
/// automatic switching.
class NetworkScreen extends ConsumerWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final statuses = ref.watch(endpointsStatusProvider);
    final p = MTThemeX.of(context).palette;

    MTEndpointStatus? statusOf(String url) => statuses.valueOrNull?[url];

    // **A lock is not a red dot**: "does not respond" sends the user
    // hunting through their router, while "rejects your credentials" is
    // fixed with two fields. Colour alone cannot tell them apart.
    Widget statusDot(String url) {
      final status = statusOf(url);
      if (status == MTEndpointStatus.unauthorized) {
        return Icon(Icons.lock_outline_rounded, size: 14, color: p.accent);
      }
      if (status == MTEndpointStatus.notMeTube) {
        return Icon(Icons.link_off_rounded, size: 14, color: p.accent);
      }
      final color = switch (status) {
        MTEndpointStatus.ok => p.ok,
        MTEndpointStatus.unreachable => p.err,
        _ => p.ink3,
      };
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
    }

    /// **A line that says what the fault is and leads to its cure.** The
    /// two cases, a rejected credential and an address that is not MeTube,
    /// were one red dot, indistinguishable from each other and from a
    /// stopped server (measured on a real device 2026-09-06).
    Widget? statusHint(String url) {
      final status = statusOf(url);
      final message = switch (status) {
        MTEndpointStatus.unauthorized =>
          '${l10n.signInRequired} — ${l10n.updateCredentials}',
        MTEndpointStatus.notMeTube => l10n.errNotMeTube,
        _ => null,
      };
      if (message == null) return null;
      final text = Padding(
        padding: const EdgeInsets.only(top: MTSpace.xs),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: p.accent),
        ),
      );
      // Credentials are fixed on another screen, so we navigate there. A
      // wrong address is fixed here in this very list, so sending the user
      // to settings would only distract.
      return status == MTEndpointStatus.unauthorized
          ? InkWell(onTap: () => context.go('/settings'), child: text)
          : text;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.networkSettings),
        actions: [
          IconButton(
            tooltip: l10n.refresh,
            onPressed: () => ref.invalidate(endpointsStatusProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          MTSpace.pagePad,
          0,
          MTSpace.pagePad,
          MTSpace.xxl,
        ),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Row(
              children: [
                Expanded(child: Text(l10n.autoUrlSwitching)),
                HelpButton(
                  title: l10n.autoUrlSwitching,
                  body: l10n.autoUrlSwitchingDesc,
                ),
              ],
            ),
            subtitle: settings.autoSwitch
                ? null
                : Text(
                    l10n.autoSwitchDisabledHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
            value: settings.autoSwitch,
            onChanged: notifier.setAutoSwitch,
          ),
          const SizedBox(height: MTSpace.md),

          MTSectionHeader(title: l10n.localNetworkSection),
          const SizedBox(height: MTSpace.xs),
          Text(
            l10n.localNetworkDesc,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: MTSpace.md),
          Row(
            children: [
              if (settings.localUrl.isNotEmpty) ...[
                statusDot(settings.localUrl),
                const SizedBox(width: MTSpace.sm),
              ],
              Expanded(
                child: TextFormField(
                  initialValue: settings.localUrl,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(labelText: l10n.localUrlLabel),
                  onFieldSubmitted: (value) async {
                    await notifier.setLocalUrl(value);
                    ref.invalidate(endpointsStatusProvider);
                  },
                ),
              ),
            ],
          ),
          if (statusHint(settings.localUrl) case final Widget hint) hint,
          const SizedBox(height: MTSpace.xl),

          MTSectionHeader(
            title: l10n.externalNetworkSection,
            trailing: '${settings.externalUrls.length}',
          ),
          const SizedBox(height: MTSpace.xs),
          Text(
            l10n.externalNetworkDesc,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: MTSpace.md),
          for (final (index, url) in settings.externalUrls.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: statusDot(url),
              title: Text(
                url,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              subtitle: statusHint(url),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (index > 0)
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                      onPressed: () async {
                        await notifier.reorderExternalUrl(index, index - 1);
                        ref.invalidate(endpointsStatusProvider);
                      },
                    ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                      color: p.err,
                    ),
                    onPressed: () async {
                      await notifier.removeExternalUrl(url);
                      ref.invalidate(endpointsStatusProvider);
                    },
                  ),
                ],
              ),
              onTap: settings.activeUrl == url
                  ? null
                  : () => notifier.adoptActiveUrl(url),
            ),
          const SizedBox(height: MTSpace.sm),
          OutlinedButton.icon(
            onPressed: () => _addExternalDialog(context, ref),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(l10n.addEndpoint),
          ),
          const SizedBox(height: MTSpace.xl),
          const ServerStatusCard(),
        ],
      ),
    );
  }

  Future<void> _addExternalDialog(BuildContext context, WidgetRef ref) async {
    final l10n = context.mtl;
    // The dialog owns the controller and disposes it; see
    // `mt_text_prompt.dart`.
    final url = await promptMTText(
      context,
      title: l10n.addEndpoint,
      confirmLabel: l10n.addEndpoint,
      labelText: l10n.endpointUrl,
      hintText: l10n.serverUrlHint,
      fieldDirection: TextDirection.ltr,
    );
    if (url == null || url.isEmpty) return;
    await ref.read(settingsProvider.notifier).addExternalUrl(url);
    ref.invalidate(endpointsStatusProvider);
  }
}
