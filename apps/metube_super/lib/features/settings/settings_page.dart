import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../subscriptions/subscriptions_screen.dart';
import '../transcripts/transcripts_section.dart';
import '../update/update_section.dart';
import 'about_screen.dart';
import 'backup_screen.dart';
import 'cookies_screen.dart';
import 'logs_screen.dart';
import 'network_screen.dart';
import 'settings_sections.dart';
import 'widgets/help_button.dart';
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
      SettingsPane.network => const NetworkScreen(),
      SettingsPane.subscriptions => const SubscriptionsScreen(),
      SettingsPane.cookies => const CookiesScreen(),
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
      // What the switch's one line cannot say: YouTube only, kept on this
      // phone and not in the backup, and how to move them.
      SettingsPane.transcripts => MTSettingsPage(
        title: l10n.settingsTranscripts,
        actions: [
          HelpButton(
            title: l10n.settingsTranscripts,
            body: l10n.transcriptsHelp,
          ),
        ],
        child: const TranscriptsSection(),
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
