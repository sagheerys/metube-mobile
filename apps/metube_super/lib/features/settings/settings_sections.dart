import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../subscriptions/subscriptions_providers.dart';
import '../transcripts/subtitles.dart';
import '../transcripts/transcripts_state.dart';
import '../update/update_state.dart';
import '../update/whats_new_prompt.dart';
import 'auto_backup.dart';
import 'cookies_screen.dart';
import 'settings_state.dart';

/// The settings sections, in the order both shapes list them.
enum SettingsPane {
  server,
  network,
  subscriptions,
  cookies,
  downloads,
  playback,
  appearance,
  transcripts,
  backup,
  updates,
  logs,
  about;

  /// **Each section has its own address**, so a message about a problem
  /// can open the very page that fixes it rather than the settings home.
  String get route => '/settings/$name';
}

/// One row of the settings home: what it opens, and what it says.
class SettingsEntry {
  const SettingsEntry(this.pane, this.icon, this.title, this.value);

  final SettingsPane pane;
  final IconData icon;
  final String title;

  /// The setting as it stands, not a description of the section.
  final String value;
}

/// The three groups the phone's home page and the tablet's list share, so
/// one order is learnt once on either device.
List<(String, List<SettingsEntry>)> settingsGroups(
  BuildContext context,
  WidgetRef ref,
) {
  final l10n = context.mtl;
  final v = _Values(context, ref);
  return [
    (
      l10n.settingsGroupServer,
      [
        SettingsEntry(
          SettingsPane.server,
          Icons.cloud_outlined,
          l10n.serverConfiguration,
          v.server(),
        ),
        SettingsEntry(
          SettingsPane.network,
          Icons.lan_outlined,
          l10n.networkSettings,
          v.network(),
        ),
        SettingsEntry(
          SettingsPane.subscriptions,
          Icons.rss_feed_rounded,
          l10n.subscriptions,
          v.subscriptions(),
        ),
        SettingsEntry(
          SettingsPane.cookies,
          Icons.cookie_outlined,
          l10n.cookies,
          v.cookies(),
        ),
      ],
    ),
    (
      l10n.settingsGroupApp,
      [
        SettingsEntry(
          SettingsPane.downloads,
          Icons.download_rounded,
          l10n.settingsDownloads,
          v.downloads(),
        ),
        SettingsEntry(
          SettingsPane.playback,
          Icons.play_arrow_rounded,
          l10n.settingsPlayback,
          v.playback(),
        ),
        SettingsEntry(
          SettingsPane.appearance,
          Icons.palette_outlined,
          l10n.appearanceAndLanguage,
          v.appearance(),
        ),
        SettingsEntry(
          SettingsPane.transcripts,
          Icons.subject_rounded,
          l10n.settingsTranscripts,
          v.transcripts(),
        ),
      ],
    ),
    (
      l10n.settingsGroupData,
      [
        SettingsEntry(
          SettingsPane.backup,
          Icons.shield_outlined,
          l10n.settingsBackup,
          v.backup(),
        ),
        SettingsEntry(
          SettingsPane.updates,
          Icons.system_update_alt_rounded,
          l10n.updates,
          v.updates(),
        ),
        SettingsEntry(
          SettingsPane.logs,
          Icons.article_outlined,
          l10n.diagnosticLogs,
          l10n.diagnosticLogsSubtitle,
        ),
        SettingsEntry(
          SettingsPane.about,
          Icons.info_outline_rounded,
          l10n.aboutApp,
          v.about(),
        ),
      ],
    ),
  ];
}

/// Each row's line. Something not known yet (the server not answered, a
/// folder not read) falls back to what the section is for, never to a
/// blank or a guess.
class _Values {
  _Values(this.context, this.ref)
    : l10n = context.mtl,
      s = ref.watch(settingsProvider);

  final BuildContext context;
  final WidgetRef ref;
  final MTLocalizations l10n;
  final SuperSettings s;

  String server() {
    if (!s.isConfigured) return l10n.settingsValueNotSet;
    final user = s.username?.trim() ?? '';
    return mtMetaLine([
      Uri.tryParse(s.activeUrl!)?.authority ?? s.activeUrl,
      user.isEmpty ? l10n.settingsValueNoPassword : user,
    ]);
  }

  String network() {
    if (s.externalUrls.isEmpty) return l10n.networkSettingsSubtitle;
    return mtMetaLine([
      s.autoSwitch ? l10n.settingsValueAuto : l10n.settingsValueManual,
      s.activeUrl == s.localUrl
          ? l10n.settingsValueLocalNow
          : l10n.settingsValueExternalNow,
    ]);
  }

  String subscriptions() {
    final state = ref.watch(subscriptionsProvider).valueOrNull;
    if (state == null || !state.supported) return l10n.subscriptionsSubtitle;
    return mtMetaLine([
      l10n.settingsValueChannels(state.sorted.length),
      if (s.notifyArrivals) l10n.settingsValueArrivals,
    ]);
  }

  String cookies() => switch (ref.watch(cookieStatusProvider).valueOrNull) {
    true => l10n.cookiesPresent,
    false => l10n.cookiesAbsent,
    null => l10n.cookiesSubtitle,
  };

  String downloads() => mtMetaLine([
    switch (s.quality) {
      Quality.best => l10n.qualityBest,
      Quality.q1080 => l10n.quality1080,
      Quality.q720 => l10n.quality720,
      Quality.q480 => l10n.quality480,
      Quality.audio => l10n.audioOnly,
    },
    if (s.wifiOnly) l10n.settingsValueWifiOnly,
    if (s.quickDownload) l10n.settingsValueQuick,
  ]);

  String playback() => s.compatiblePlayback
      ? l10n.settingsValueCompatOn
      : l10n.settingsValueCompatOff;

  String appearance() => mtMetaLine([
    switch (s.themeMode) {
      ThemeMode.system => l10n.themeSystem,
      ThemeMode.light => l10n.themeLight,
      ThemeMode.dark => l10n.themeDark,
    },
    // Following the phone, it names the language in use: "System" twice
    // over said nothing.
    mtLanguageName(
      s.localeCode ?? Localizations.localeOf(context).languageCode,
    ),
  ]);

  String transcripts() {
    if (!(ref.watch(transcriptsEnabledProvider).valueOrNull ?? false)) {
      return l10n.settingsValueOff;
    }
    final stats = ref.watch(transcriptStatsProvider).valueOrNull;
    return mtMetaLine([
      l10n.settingsValueOn,
      if (stats != null) l10n.transcriptsClips(stats.clips),
      if (ref.watch(subtitlePrefsProvider).shown.value)
        l10n.settingsValueSubtitlesShown,
    ]);
  }

  String backup() => switch (ref.watch(latestBackupProvider).valueOrNull) {
    final at? => l10n.lastBackup(mtTimeAgo(context, at)),
    null => l10n.backupSettingsSubtitle,
  };

  String updates() {
    final state = ref.watch(updateControllerProvider);
    if (state.release case final release?) {
      return l10n.updateVersionAvailable(release.version.toString());
    }
    return mtMetaLine([
      ref.watch(installedVersionProvider).valueOrNull?.$1,
      if (state.autoCheck) l10n.autoCheckUpdates,
    ]);
  }

  String about() => switch (ref.watch(installedVersionProvider).valueOrNull) {
    (final version, _) => '${l10n.version} $version',
    null => l10n.aboutDescriptionSuper,
  };
}
