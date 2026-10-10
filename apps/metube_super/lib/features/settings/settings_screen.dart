import 'package:flutter/material.dart';
import 'package:mt_ui/mt_ui.dart';

import '../transcripts/transcripts_section.dart';
import '../update/update_section.dart';
import 'settings_hub.dart';
import 'widgets/server_fields.dart';
import 'widgets/server_status_card.dart';
import 'widgets/settings_fields.dart';

/// Settings: the server card first, About last. On a tablet held sideways
/// the same sections open in two panes ([SettingsHub]).
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
            const SizedBox(height: MTSpace.xl),
            const ServerFields(),
            const SizedBox(height: MTSpace.sm),
            // Endpoint management (Super only).
            SettingsNavTile(
              icon: Icons.lan_outlined,
              title: l10n.networkSettings,
              subtitle: l10n.networkSettingsSubtitle,
              route: '/settings/network',
            ),
            // Channels the server follows. It lives beside the network row
            // because it is the server's work, not the phone's.
            SettingsNavTile(
              icon: Icons.rss_feed_rounded,
              title: l10n.subscriptions,
              subtitle: l10n.subscriptionsSubtitle,
              route: '/settings/subscriptions',
            ),
            // Something only the server's owner can do.
            SettingsNavTile(
              icon: Icons.cookie_outlined,
              title: l10n.cookies,
              subtitle: l10n.cookiesSubtitle,
              route: '/settings/cookies',
            ),
            const SizedBox(height: MTSpace.xl),
            const PreferencesFields(),
            const SizedBox(height: MTSpace.lg),
            const AppearanceFields(),
            const SizedBox(height: MTSpace.xl),
            const TranscriptsSection(),
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
              subtitle: l10n.aboutDescriptionSuper,
              route: '/settings/about',
            ),
          ],
        ),
      ),
    );
  }
}
