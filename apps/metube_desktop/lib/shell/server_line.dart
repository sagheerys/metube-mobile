import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../data/addresses_data.dart';
import '../data/library_data.dart';
import '../data/server_release.dart';
import '../router.dart';
import 'context_menu.dart';

/// The foot of the sidebar: which server address is in use and whether it
/// answers, and the switch to another saved one in a click. Switching is
/// by hand only, as in Addresses: nothing changes by itself.
///
/// **A server that answers is not announced**: the address beside a quiet
/// server mark. Only a server that is still being reached, or does not
/// answer, gets its coloured dot; a green dot always on was decoration.
class SidebarServerLine extends ConsumerWidget {
  const SidebarServerLine({super.key, required this.narrow});

  final bool narrow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(serverConfigProvider);
    if (config == null) return const SizedBox.shrink();
    final p = MTThemeX.of(context).palette;
    final l = context.mtl;
    final text = Theme.of(context).textTheme;
    final addresses = ref.watch(addressesProvider);
    final active = addresses.active ?? config.baseUrl;
    final host = ServerConfig.hostLabel(active);
    final history = ref.watch(historyProvider);
    final (status, color) = switch (history) {
      AsyncData() => (l.serverStatusConnected, p.ok),
      AsyncError() => (l.serverStatusOffline, p.err),
      _ => (l.serverStatusChecking, p.ink3),
    };
    final release = ref.watch(serverReleaseProvider).valueOrNull;
    final update = release != null && release.isOutdated
        ? l.serverVersionOutdated(release.latest!)
        : null;
    final dot = history is AsyncData
        ? MTIcon(
            MTIcons.server,
            key: const ValueKey('server-quiet'),
            size: MTSpace.md,
            color: p.ink3,
          )
        : Container(
            key: const ValueKey('server-dot'),
            width: MTSpace.xs,
            height: MTSpace.xs,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          );
    return MTShortcutTooltip(
      message: [status, host, ?update].join(' · '),
      child: Semantics(
        button: true,
        label: [
          '${l.desktopAddresses}: $host',
          status,
          ?update,
        ].join(l.listSeparator),
        excludeSemantics: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(MTCorners.desktop.chip),
          onTapUp: (tap) =>
              unawaited(_choose(context, ref, tap.globalPosition, active)),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MTSpace.sm,
              vertical: MTSpace.xs,
            ),
            child: narrow
                ? Center(child: dot)
                : Row(
                    children: [
                      dot,
                      const SizedBox(width: MTSpace.sm),
                      Expanded(
                        // Read left to right, but set beside the dot in
                        // either language.
                        child: Text(
                          mtLtrRun(host),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.labelSmall?.copyWith(color: p.ink2),
                        ),
                      ),
                      // Information, not a fault: the ink's own shade, and the
                      // words in the tooltip.
                      if (update != null) ...[
                        const SizedBox(width: MTSpace.xs),
                        Container(
                          key: const ValueKey('server-outdated'),
                          width: MTSpace.xs,
                          height: MTSpace.xs,
                          decoration: BoxDecoration(
                            color: p.ink2,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: MTSpace.xs),
                      ],
                      MTIcon(MTIcons.swap, size: MTSpace.md, color: p.ink3),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// The saved addresses to choose from; with only one there is nothing to
  /// switch to, so Addresses opens to add another.
  Future<void> _choose(
    BuildContext context,
    WidgetRef ref,
    Offset at,
    String active,
  ) async {
    final urls = ref.read(addressesProvider).urls;
    if (urls.length < 2) {
      context.go(EmberSettingsPane.network.route);
      return;
    }
    final chosen = await showEmberMenu<String>(context, at, [
      for (final url in urls)
        EmberMenuEntry(
          url,
          url == active ? MTIcons.check : MTIcons.server,
          ServerConfig.hostLabel(url),
        ),
    ]);
    if (chosen != null && chosen != active) {
      await ref.read(addressesProvider.notifier).use(chosen);
    }
  }
}
