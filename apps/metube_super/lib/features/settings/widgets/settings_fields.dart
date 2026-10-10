import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../../di.dart';
import 'help_button.dart';

/// A row that opens one of the settings screens.
class SettingsNavTile extends StatelessWidget {
  const SettingsNavTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String route;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    trailing: const Icon(Icons.chevron_right_rounded),
    onTap: () => context.go(route),
  );
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
    subtitle: Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
    value: value,
    onChanged: onChanged,
  );
}

/// The download and playback preferences.
class PreferencesFields extends ConsumerWidget {
  const PreferencesFields({super.key, this.showHeader = true});

  /// False under a pane title that already names the section.
  final bool showHeader;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          MTSectionHeader(title: l10n.preferences),
          const SizedBox(height: MTSpace.md),
        ],
        Row(
          children: [
            Expanded(
              child: DropdownMenu<Quality>(
                initialSelection: settings.quality,
                label: Text(l10n.defaultQuality),
                expandedInsets: EdgeInsets.zero,
                dropdownMenuEntries: [
                  DropdownMenuEntry(
                    value: Quality.best,
                    label: l10n.qualityBest,
                  ),
                  DropdownMenuEntry(
                    value: Quality.q1080,
                    label: l10n.quality1080,
                  ),
                  DropdownMenuEntry(
                    value: Quality.q720,
                    label: l10n.quality720,
                  ),
                  DropdownMenuEntry(
                    value: Quality.q480,
                    label: l10n.quality480,
                  ),
                  DropdownMenuEntry(
                    value: Quality.audio,
                    label: l10n.audioOnly,
                  ),
                ],
                onSelected: (q) => q == null ? null : notifier.setQuality(q),
              ),
            ),
            HelpButton(title: l10n.defaultQuality, body: l10n.qualityHelper),
          ],
        ),
        // **The default quality used to be a setting with no effect**: it
        // filled in the add sheet and the user re-chose it every time. With
        // "quick download" it becomes the actual decision, and the sheet is
        // skipped entirely.
        _SwitchTile(
          title: l10n.quickDownload,
          subtitle: l10n.quickDownloadHelp,
          value: settings.quickDownload,
          onChanged: notifier.setQuickDownload,
        ),
        _SwitchTile(
          title: l10n.wifiOnly,
          subtitle: l10n.wifiOnlyHelp,
          value: settings.wifiOnly,
          onChanged: notifier.setWifiOnly,
        ),
        _SwitchTile(
          title: l10n.autoRetry,
          subtitle: l10n.autoRetryHelp,
          value: settings.autoRetry,
          onChanged: notifier.setAutoRetry,
        ),
        // The arrivals notice sits beside the other download preferences,
        // because that is what it governs: what the server fetched without
        // being asked.
        _SwitchTile(
          title: l10n.notifyArrivals,
          subtitle: l10n.notifyArrivalsDesc,
          value: settings.notifyArrivals,
          onChanged: notifier.setNotifyArrivals,
        ),
        _SwitchTile(
          title: l10n.compatiblePlayback,
          subtitle: l10n.compatiblePlaybackHelp,
          value: settings.compatiblePlayback,
          onChanged: notifier.setCompatiblePlayback,
        ),
      ],
    );
  }
}

/// The theme and the language.
class AppearanceFields extends ConsumerWidget {
  const AppearanceFields({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final settings = ref.watch(settingsProvider);
    final title = Theme.of(context).textTheme.titleSmall;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.theme, style: title),
        const SizedBox(height: MTSpace.xs),
        SegmentedButton<ThemeMode>(
          segments: [
            ButtonSegment(
              value: ThemeMode.system,
              label: Text(l10n.themeSystem),
            ),
            ButtonSegment(value: ThemeMode.light, label: Text(l10n.themeLight)),
            ButtonSegment(value: ThemeMode.dark, label: Text(l10n.themeDark)),
          ],
          selected: {settings.themeMode},
          onSelectionChanged: (selection) =>
              ref.read(settingsProvider.notifier).setThemeMode(selection.first),
        ),
        const SizedBox(height: MTSpace.lg),
        Text(l10n.language, style: title),
        const SizedBox(height: MTSpace.xs),
        // **"System" is a choice, not an implicit state.** An empty value
        // did mean "follow the phone", but the switch displayed it as
        // "Arabic", so someone with an English device read an English
        // interface beside a switch claiming Arabic, and the first touch
        // pinned a language with no way back.
        // **A row that opens a screen, not a segmented button** (requested
        // 2026-09-08): `SegmentedButton` divides the width by the number of
        // options, so three fit 360dp **and six break**, and the declared
        // plan is to support the common languages.
        SettingsNavTile(
          icon: Icons.translate_rounded,
          title: l10n.language,
          subtitle: settings.localeCode == null
              ? l10n.languageSystem
              : mtLanguageName(settings.localeCode!),
          route: '/settings/language',
        ),
      ],
    );
  }
}
