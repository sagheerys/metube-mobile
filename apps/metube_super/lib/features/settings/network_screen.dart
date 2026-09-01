import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import 'widgets/help_button.dart';
import 'widgets/server_status_card.dart';

/// حالة وصول كل رابط (نقاط حية) — فحص متوازٍ 4s.
final endpointsStatusProvider =
    FutureProvider<Map<String, bool>>((ref) async {
  final settings = ref.watch(settingsProvider);
  final resolver = ref.watch(endpointResolverProvider);
  if (settings.candidateUrls.isEmpty) return {};
  return resolver.probeAll(settings.candidateUrls);
});

/// إدارة روابط السيرفر (م-28/ر-9): محلي + خارجية مرتبة + تبديل تلقائي.
class NetworkScreen extends ConsumerWidget {
  const NetworkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final statuses = ref.watch(endpointsStatusProvider);
    final p = MTThemeX.of(context).palette;

    Widget statusDot(String url) {
      final reachable = statuses.value?[url];
      final color = switch (reachable) {
        true => p.ok,
        false => p.err,
        null => p.ink3,
      };
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
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
            MTSpace.pagePad, 0, MTSpace.pagePad, MTSpace.xxl),
        children: [
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Row(children: [
              Expanded(child: Text(l10n.autoUrlSwitching)),
              HelpButton(
                  title: l10n.autoUrlSwitching,
                  body: l10n.autoUrlSwitchingDesc),
            ]),
            subtitle: settings.autoSwitch
                ? null
                : Text(l10n.autoSwitchDisabledHint,
                    style: Theme.of(context).textTheme.bodySmall),
            value: settings.autoSwitch,
            onChanged: notifier.setAutoSwitch,
          ),
          const SizedBox(height: MTSpace.md),

          MTSectionHeader(title: l10n.localNetworkSection),
          const SizedBox(height: MTSpace.xs),
          Text(l10n.localNetworkDesc,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: MTSpace.md),
          Row(children: [
            if (settings.localUrl.isNotEmpty) ...[
              statusDot(settings.localUrl),
              const SizedBox(width: MTSpace.sm),
            ],
            Expanded(
              child: TextFormField(
                initialValue: settings.localUrl,
                textDirection: TextDirection.ltr,
                decoration:
                    InputDecoration(labelText: l10n.localUrlLabel),
                onFieldSubmitted: (value) async {
                  await notifier.setLocalUrl(value);
                  ref.invalidate(endpointsStatusProvider);
                },
              ),
            ),
          ]),
          const SizedBox(height: MTSpace.xl),

          MTSectionHeader(
              title: l10n.externalNetworkSection,
              trailing: '${settings.externalUrls.length}'),
          const SizedBox(height: MTSpace.xs),
          Text(l10n.externalNetworkDesc,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: MTSpace.md),
          for (final (index, url) in settings.externalUrls.indexed)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: statusDot(url),
              title: Text(url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.bodyMedium),
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
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 18, color: p.err),
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

  void _addExternalDialog(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.addEndpoint),
        content: TextField(
          controller: controller,
          autofocus: true,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
              labelText: l10n.endpointUrl, hintText: l10n.serverUrlHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await ref
                  .read(settingsProvider.notifier)
                  .addExternalUrl(controller.text);
              ref.invalidate(endpointsStatusProvider);
            },
            child: Text(l10n.addEndpoint),
          ),
        ],
      ),
    );
  }
}
