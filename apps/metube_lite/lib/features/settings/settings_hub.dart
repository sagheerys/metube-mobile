import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../update/update_section.dart';
import 'about_screen.dart';
import 'backup_screen.dart';
import 'logs_screen.dart';
import 'widgets/server_fields.dart';
import 'widgets/server_keeps_files_notice.dart';
import 'widgets/server_status_card.dart';
import 'widgets/settings_fields.dart';

/// The settings sections, as the tablet's list names them.
enum SettingsPane {
  server,
  preferences,
  appearance,
  backup,
  updates,
  logs,
  about,
}

/// **Settings in two panes** on a tablet held sideways (2026-10-10): the
/// sections on one side, the chosen one open on the other, the way
/// Android's own settings read on a tablet. A phone keeps one long page.
class SettingsHub extends StatelessWidget {
  const SettingsHub({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  final SettingsPane selected;
  final ValueChanged<SettingsPane> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    Widget row(SettingsPane pane, IconData icon, String title, String sub) =>
        SettingsHubRow(
          icon: icon,
          title: title,
          subtitle: sub,
          selected: pane == selected,
          onTap: () => onSelect(pane),
        );
    return Row(
      children: [
        SizedBox(
          width: MTBreakpoint.sidePanel,
          child: Scaffold(
            appBar: AppBar(title: Text(l10n.settings)),
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
                SettingsHubGroup(l10n.settingsGroupServer),
                row(
                  SettingsPane.server,
                  Icons.cloud_outlined,
                  l10n.serverConfiguration,
                  l10n.serverConfigurationSubtitle,
                ),
                SettingsHubGroup(l10n.settingsGroupApp),
                row(
                  SettingsPane.preferences,
                  Icons.tune_rounded,
                  l10n.preferences,
                  l10n.preferencesSubtitle,
                ),
                row(
                  SettingsPane.appearance,
                  Icons.palette_outlined,
                  l10n.appearanceAndLanguage,
                  l10n.appearanceSubtitle,
                ),
                SettingsHubGroup(l10n.settingsGroupData),
                row(
                  SettingsPane.backup,
                  Icons.shield_outlined,
                  l10n.backupSettings,
                  l10n.backupSettingsSubtitle,
                ),
                row(
                  SettingsPane.updates,
                  Icons.system_update_alt_rounded,
                  l10n.updates,
                  l10n.checkForUpdates,
                ),
                row(
                  SettingsPane.logs,
                  Icons.article_outlined,
                  l10n.diagnosticLogs,
                  l10n.diagnosticLogsSubtitle,
                ),
                row(
                  SettingsPane.about,
                  Icons.info_outline_rounded,
                  l10n.aboutApp,
                  l10n.aboutDescriptionLite,
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
            child: _detail(context, l10n),
          ),
        ),
      ],
    );
  }

  /// The screens that already exist open as they are; the sections that
  /// lived inside the long page get a pane of their own.
  Widget _detail(BuildContext context, MTLocalizations l10n) =>
      switch (selected) {
        SettingsPane.server => SettingsHubPane(
          title: l10n.serverConfiguration,
          child: const ServerFields(showHeader: false),
        ),
        SettingsPane.preferences => SettingsHubPane(
          title: l10n.preferences,
          child: const PreferencesFields(showHeader: false),
        ),
        SettingsPane.appearance => SettingsHubPane(
          title: l10n.appearanceAndLanguage,
          child: const AppearanceFields(),
        ),
        SettingsPane.backup => const BackupScreen(),
        SettingsPane.updates => SettingsHubPane(
          title: l10n.updates,
          child: const UpdateSection(),
        ),
        SettingsPane.logs => const LogsScreen(),
        SettingsPane.about => const AboutScreen(),
      };
}

/// A small heading over a group of sections.
class SettingsHubGroup extends StatelessWidget {
  const SettingsHubGroup(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.fromSTEB(
      MTSpace.md,
      MTSpace.lg,
      MTSpace.md,
      MTSpace.xs,
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelSmall!.copyWith(
        color: MTThemeX.of(context).palette.ink3,
        letterSpacing: 0.8,
      ),
    ),
  );
}

/// One section in the list; the open one is lit in the accent.
class SettingsHubRow extends StatelessWidget {
  const SettingsHubRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    return ListTile(
      selected: selected,
      selectedTileColor: p.accentSoft,
      selectedColor: p.accentInk,
      iconColor: p.ink2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MTRadius.card),
      ),
      leading: Icon(icon),
      title: Text(
        title,
        style: selected ? const TextStyle(fontWeight: FontWeight.w700) : null,
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: onTap,
    );
  }
}

/// A section that lived inside the phone's long page, given its own pane.
class SettingsHubPane extends StatelessWidget {
  const SettingsHubPane({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: MTReadableWidth(
      child: ListView(
        // Room above the first field's floating label, which a page title
        // sits right on top of.
        padding: const EdgeInsets.fromLTRB(
          MTSpace.pagePad,
          MTSpace.md,
          MTSpace.pagePad,
          120,
        ),
        children: [child],
      ),
    ),
  );
}
