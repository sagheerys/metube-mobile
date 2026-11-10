import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/appearance_data.dart';
import '../../data/channels_data.dart';
import '../../data/choices_data.dart';
import '../../data/library_data.dart';
import '../../data/update_data.dart';
import '../../router.dart';
import '../../shell/ui_zoom.dart';
import 'simple_panes.dart';
import 'transcripts_pane.dart';

/// The line under a section's name in the list: the setting as it stands,
/// not a description. Null when there is nothing short and certain to say,
/// rather than a guess or a blank.
String? paneValue(BuildContext context, WidgetRef ref, EmberSettingsPane pane) {
  final l = context.mtl;
  switch (pane) {
    case EmberSettingsPane.server:
      final config = ref.watch(serverConfigProvider);
      if (config == null) return l.settingsValueNotSet;
      return ServerConfig.hostLabel(config.baseUrl);
    case EmberSettingsPane.subscriptions:
      final channels = ref.watch(channelsProvider).valueOrNull?.subscriptions;
      return channels == null ? null : l.settingsValueChannels(channels.length);
    case EmberSettingsPane.downloads:
      final quality = ref.watch(defaultQualityProvider);
      return qualityLabels(l).firstWhere((q) => q.$1 == quality).$2;
    case EmberSettingsPane.appearance:
      final look = ref.watch(appearanceProvider);
      return mtMetaLine([
        switch (look.theme) {
          ThemeMode.system => l.themeSystem,
          ThemeMode.light => l.themeLight,
          ThemeMode.dark => l.themeDark,
        },
        // Following Windows, it names the language in use: "System" twice
        // over would say nothing.
        mtLanguageName(
          look.locale ?? Localizations.localeOf(context).languageCode,
        ),
        ref.watch(uiZoomProvider).percent,
      ]);
    case EmberSettingsPane.transcripts:
      final summary = ref.watch(transcriptsSummaryProvider).valueOrNull;
      return summary == null ? null : l.transcriptsClips(summary.$1);
    case EmberSettingsPane.updates:
      if (ref.watch(updateProvider).release case final release?) {
        return l.updateVersionAvailable(release.version.toString());
      }
      return ref.watch(installedVersionProvider).valueOrNull;
    case EmberSettingsPane.about:
      final version = ref.watch(installedVersionProvider).valueOrNull;
      return version == null ? null : '${l.version} $version';
    default:
      return null;
  }
}
