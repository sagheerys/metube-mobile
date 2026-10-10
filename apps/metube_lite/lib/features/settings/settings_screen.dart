import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../update/update_section.dart';
import 'settings_hub.dart';
import 'widgets/server_fields.dart';
import 'widgets/server_keeps_files_notice.dart';
import 'widgets/server_status_card.dart';
import 'widgets/settings_fields.dart';

/// Settings: the server card first, About last. Lite has no endpoint
/// management, since there is one URL for the family server. On a tablet
/// held sideways the same sections open in two panes ([SettingsHub]).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Kept here, above both shapes, so turning the tablet does not lose the
  /// open section.
  SettingsPane _pane = SettingsPane.server;

  @override
  Widget build(BuildContext context) {
    if (MTAdaptiveScaffold.hasEndPane(context)) {
      return SettingsHub(
        selected: _pane,
        onSelect: (pane) => setState(() => _pane = pane),
      );
    }
    final l10n = context.mtl;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: MTReadableWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            MTSpace.pagePad,
            0,
            MTSpace.pagePad,
            120,
          ),
          children: [
            const ServerStatusCard(),
            const ServerKeepsFilesNotice(),
            const SizedBox(height: MTSpace.xl),
            const ServerFields(),
            const SizedBox(height: MTSpace.xl),
            const PreferencesFields(),
            const SizedBox(height: MTSpace.lg),
            const AppearanceFields(),
            const SizedBox(height: MTSpace.xl),

            // Data and diagnostics, then About last.
            MTSectionHeader(title: l10n.backupSettings),
            SettingsNavTile(
              icon: Icons.shield_outlined,
              title: l10n.backupSettings,
              subtitle: l10n.backupSettingsSubtitle,
              route: '/settings/backup',
            ),
            SettingsNavTile(
              icon: Icons.article_outlined,
              title: l10n.diagnosticLogs,
              subtitle: l10n.diagnosticLogsSubtitle,
              route: '/settings/logs',
            ),
            const SizedBox(height: MTSpace.xl),
            const UpdateSection(),
            const SizedBox(height: MTSpace.xl),
            MTSectionHeader(title: l10n.about),
            SettingsNavTile(
              icon: Icons.info_outline_rounded,
              title: l10n.aboutApp,
              subtitle: l10n.aboutDescriptionLite,
              route: '/settings/about',
            ),
          ],
        ),
      ),
    );
  }
}
