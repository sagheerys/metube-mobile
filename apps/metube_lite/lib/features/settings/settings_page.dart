import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../update/update_section.dart';
import 'about_screen.dart';
import 'backup_screen.dart';
import 'logs_screen.dart';
import 'settings_sections.dart';
import 'widgets/server_fields.dart';
import 'widgets/settings_fields.dart';

/// A section's page: pushed on a phone, open beside the list on a tablet
/// held sideways. The screens that existed before the home page open as
/// they are.
class SettingsPage extends StatelessWidget {
  const SettingsPage(this.pane, {super.key});

  final SettingsPane pane;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    return switch (pane) {
      SettingsPane.server => MTSettingsPage(
        title: l10n.serverConfiguration,
        child: const ServerFields(showHeader: false),
      ),
      SettingsPane.downloads => MTSettingsPage(
        title: l10n.settingsDownloads,
        child: const DownloadFields(),
      ),
      SettingsPane.playback => MTSettingsPage(
        title: l10n.settingsPlayback,
        child: const PlaybackFields(),
      ),
      SettingsPane.appearance => MTSettingsPage(
        title: l10n.appearanceAndLanguage,
        child: const AppearanceFields(),
      ),
      SettingsPane.backup => const BackupScreen(),
      SettingsPane.updates => MTSettingsPage(
        title: l10n.updates,
        child: const UpdateSection(),
      ),
      SettingsPane.logs => const LogsScreen(),
      SettingsPane.about => const AboutScreen(),
    };
  }
}
