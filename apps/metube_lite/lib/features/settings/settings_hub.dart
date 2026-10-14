import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import 'settings_page.dart';
import 'settings_sections.dart';
import 'widgets/server_keeps_files_notice.dart';
import 'widgets/server_status_card.dart';

/// **Settings in two panes** on a tablet held sideways (2026-10-10): the
/// rows of the phone's home page on one side, the chosen section open on
/// the other, the way Android's own settings read on a tablet.
class SettingsHub extends ConsumerWidget {
  const SettingsHub({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final SettingsPane selected;
  final ValueChanged<SettingsPane> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Row(
    children: [
      SizedBox(
        width: MTBreakpoint.sidePanel,
        child: Scaffold(
          appBar: AppBar(title: Text(context.mtl.settings)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              MTSpace.md,
              0,
              MTSpace.md,
              MTSpace.xl,
            ),
            children: [
              const ServerStatusCard(),
              const ServerKeepsFilesNotice(),
              for (final (title, entries) in settingsGroups(context, ref))
                MTSettingsGroup(
                  title: title,
                  divided: false,
                  rows: [
                    for (final e in entries)
                      MTSettingsRow(
                        icon: e.icon,
                        title: e.title,
                        value: e.value,
                        selected: e.pane == selected,
                        chevron: false,
                        onTap: () => onSelect(e.pane),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
      VerticalDivider(
        width: 1,
        thickness: 1,
        color: MTThemeX.of(context).palette.line,
      ),
      Expanded(
        child: KeyedSubtree(
          key: ValueKey(selected),
          child: SettingsPage(selected),
        ),
      ),
    ],
  );
}
