import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../data/choices_data.dart';
import '../../data/desktop_habits.dart';
import '../../data/downloads_data.dart';
import '../../data/hints_data.dart';
import '../../data/library_data.dart';
import '../../shell/pill.dart';
import '../setup/setup_dialog.dart';
import 'appearance_pane.dart';
import 'browser_button.dart';
import 'server_version_line.dart';
import '../../shell/folded_text.dart';

/// One setting: its name, a line saying what it does, and its control at
/// the line's far end, with a hairline under it, so a pane reads as a list
/// of separate settings (the settings design, Desktop 08).
class SettingLine extends StatelessWidget {
  const SettingLine({
    super.key,
    required this.title,
    this.hint,
    this.value,
    this.trailing,
  });

  final String title;
  final String? hint;

  /// What it is set to, under the name (a folder, an address).
  final String? value;
  final Widget? trailing;

  /// The most of the line the control may take; the name has the rest.
  static const double controlShare = 0.45;

  @override
  Widget build(BuildContext context) {
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: p.line,
            width: MTThemeX.of(context).hairline,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: MTSpace.md),
        child: LayoutBuilder(
          builder: (context, box) => Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.bodyLarge?.copyWith(color: p.ink)),
                    if (value case final value?)
                      Text(
                        value,
                        textDirection: TextDirection.ltr,
                        style: text.bodySmall?.copyWith(color: p.ink2),
                      ),
                    if (hint case final hint?)
                      FoldedText(
                        hint,
                        style: text.labelSmall?.copyWith(color: p.ink3),
                      ),
                  ],
                ),
              ),
              if (trailing case final trailing?) ...[
                const SizedBox(width: MTSpace.lg),
                // At the far end, as wide as it needs up to its share: a
                // long label at a large text size wraps instead of
                // spilling.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: box.maxWidth * controlShare,
                  ),
                  child: trailing,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A setting that is on or off; [onChanged] null draws it unavailable.
class SwitchLine extends StatelessWidget {
  const SwitchLine({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.hint,
  });

  final String title;
  final String? hint;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  /// One control for a screen reader: the switch is read with its title
  /// and hint, not as a nameless toggle beside them.
  Widget build(BuildContext context) => MergeSemantics(
    child: SettingLine(
      title: title,
      hint: hint,
      trailing: MTSwitch(value: value, onChanged: onChanged),
    ),
  );
}

/// The server: where it is and who signs in. The account is set up by the
/// first-run setup; the address is chosen in Addresses.
class ServerPane extends ConsumerWidget {
  const ServerPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final config = ref.watch(serverConfigProvider);
    final again = MTLinkButton(
      label: config == null ? l.desktopSetupConnect : l.desktopSetupAgain,
      onPressed: () => unawaited(showSetupDialog(context)),
    );
    if (config == null) {
      return SettingLine(title: l.serverStatusUnconfigured, trailing: again);
    }
    final history = ref.watch(historyProvider);
    final status = switch (history) {
      AsyncData() => l.serverStatusConnected,
      AsyncError() => l.serverStatusOffline,
      _ => l.serverStatusChecking,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingLine(
          title: l.serverUrl,
          value: config.baseUrl,
          hint: status,
          trailing: again,
        ),
        if (config.username case final user? when user.isNotEmpty)
          SettingLine(title: l.username, value: user),
        // Without it, a server locked by a token alone looks unprotected.
        if (config.access?.isComplete ?? false)
          SettingLine(
            title: l.settingsValueCloudflare,
            value: l.cloudflareTokenSaved,
          ),
        const ServerVersionLine(),
      ],
    );
  }
}

/// How links are added: the quality an add starts with, and the
/// transcript first.
class DownloadsPane extends ConsumerWidget {
  const DownloadsPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final quality = ref.watch(defaultQualityProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ChoiceGroup(
          title: l.defaultQuality,
          hint: l.desktopDefaultQualityHint,
          children: [
            for (final (choice, label) in qualityLabels(l))
              EmberPill(
                label: label,
                selected: quality == choice,
                onTap: () => unawaited(
                  ref.read(defaultQualityProvider.notifier).set(choice),
                ),
              ),
          ],
        ),
        SwitchLine(
          title: l.desktopTranscriptFirst,
          hint: l.transcriptsSearchHelp,
          value: ref.watch(transcriptsFirstProvider),
          onChanged: (on) =>
              unawaited(ref.read(transcriptsFirstProvider.notifier).set(on)),
        ),
      ],
    );
  }
}

/// The qualities in the order offered, with their names.
List<(Quality, String)> qualityLabels(MTLocalizations l) => [
  (Quality.best, l.qualityBest),
  (Quality.q1080, l.quality1080),
  (Quality.q720, l.quality720),
  (Quality.q480, l.quality480),
  (Quality.audio, l.qualityAudio),
];

/// The computer's own habits, all off until chosen: the tray, starting
/// with Windows, and the play key from any app.
class DesktopPane extends ConsumerWidget {
  const DesktopPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.mtl;
    final hints = ref.watch(hintsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchLine(
          title: l.desktopTrayOnClose,
          hint: l.desktopTrayOnCloseHint,
          value: ref.watch(closeToTrayProvider),
          onChanged: (on) =>
              unawaited(ref.read(closeToTrayProvider.notifier).set(on)),
        ),
        SwitchLine(
          title: l.desktopStartWithWindows,
          hint: l.desktopStartWithWindowsHint,
          value: ref.watch(startWithWindowsProvider),
          onChanged: (on) => unawaited(
            _ask(
              context,
              ref.read(startWithWindowsProvider.notifier).set(on),
              l.desktopStartWithWindowsRefused,
            ),
          ),
        ),
        SwitchLine(
          title: l.desktopGlobalShortcut,
          hint: l.desktopGlobalShortcutHint(GlobalPlayKey.label),
          value: ref.watch(globalPlayKeyProvider),
          onChanged: (on) => unawaited(
            _ask(
              context,
              ref.read(globalPlayKeyProvider.notifier).set(on),
              l.desktopGlobalShortcutTaken(GlobalPlayKey.label),
            ),
          ),
        ),
        SwitchLine(
          title: l.desktopOfferCopiedLinks,
          hint: l.desktopOfferCopiedLinksHint,
          value: ref.watch(offerCopiedLinksProvider),
          onChanged: (on) =>
              unawaited(ref.read(offerCopiedLinksProvider.notifier).set(on)),
        ),
        const BrowserButtonLine(),
        SwitchLine(
          title: l.desktopHints,
          hint: l.desktopHintsHint,
          value: hints.on,
          onChanged: (on) =>
              unawaited(ref.read(hintsProvider.notifier).setOn(on)),
        ),
        if (hints.on && hints.seen.isNotEmpty)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: MTLinkButton(
              label: l.desktopHintsAgain,
              onPressed: () =>
                  unawaited(ref.read(hintsProvider.notifier).showAgain()),
            ),
          ),
      ],
    );
  }
}

/// Says so when Windows refused what a switch asked.
Future<void> _ask(
  BuildContext context,
  Future<bool> asked,
  String refused,
) async {
  if (await asked || !context.mounted) return;
  showMTNotice(context, message: refused, kind: MTNoticeKind.failed);
}
