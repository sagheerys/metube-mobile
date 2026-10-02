import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'update_state.dart';

/// The running version, and whether Android installed it over an older
/// copy. **A provider of its own** so tests can replace it:
/// `package_info_plus` is a native channel.
final installedVersionProvider = FutureProvider<(String, bool)>((ref) async {
  final info = await PackageInfo.fromPlatform();
  final installed = info.installTime;
  final updated = info.updateTime;
  // On a fresh install the two times are the same moment.
  final upgraded =
      installed != null &&
      updated != null &&
      updated.difference(installed) > const Duration(minutes: 1);
  return (info.version, upgraded);
});

final whatsNewServiceProvider = Provider(
  (ref) => WhatsNewService(
    prefs: ref.watch(updatePrefsProvider),
    checker: ref.watch(updateCheckerProvider),
  ),
);

enum WhatsNewOutcome {
  shown,
  nothing,

  /// Something else was open above the shell; ask again on the next resume.
  later,
}

/// Shows "what's new" if this is the first run of a newer version.
///
/// Never an error: a missing plugin or a failed read is "nothing".
Future<WhatsNewOutcome> maybeShowWhatsNew(
  BuildContext context,
  WidgetRef ref,
) async {
  // Launch and every resume both ask, and the notes may take a network
  // round trip: a second ask while the first waits would show it twice.
  if (_checking) return WhatsNewOutcome.later;
  _checking = true;
  try {
    return await _maybeShow(context, ref);
  } finally {
    _checking = false;
  }
}

bool _checking = false;
bool _opening = false;

Future<WhatsNewOutcome> _maybeShow(BuildContext context, WidgetRef ref) async {
  final WhatsNew? pending;
  try {
    final (version, upgraded) = await ref.read(installedVersionProvider.future);
    pending = await ref
        .read(whatsNewServiceProvider)
        .pending(currentVersion: version, upgraded: upgraded);
  } catch (_) {
    return WhatsNewOutcome.nothing;
  }
  if (pending == null) return WhatsNewOutcome.nothing;
  if (!context.mounted || MTRouteDepth.depth.value != 0) {
    return WhatsNewOutcome.later;
  }
  await ref.read(whatsNewServiceProvider).markSeen(pending.version);
  if (!context.mounted) return WhatsNewOutcome.later;
  _show(context, pending);
  return WhatsNewOutcome.shown;
}

/// The same sheet on request, from settings, for the version running now.
///
/// A second tap while the notes are still on their way does nothing, so
/// two sheets never stack.
Future<void> showWhatsNewNow(BuildContext context, WidgetRef ref) async {
  if (_opening) return;
  _opening = true;
  final WhatsNew? notes;
  try {
    final (version, _) = await ref.read(installedVersionProvider.future);
    notes = await ref.read(whatsNewServiceProvider).of(version);
  } catch (_) {
    return;
  } finally {
    _opening = false;
  }
  if (notes == null || !context.mounted) return;
  _show(context, notes);
}

void _show(BuildContext context, WhatsNew notes) {
  final arabic = Localizations.localeOf(context).languageCode == 'ar';
  showMTWhatsNewSheet(
    context,
    version: notes.version,
    notes: mtReleaseNotesFor(notes.notes, arabic: arabic, app: 'lite'),
    onOpenPage: () => launchUrl(
      Uri.parse(notes.pageUrl),
      mode: LaunchMode.externalApplication,
    ),
  );
}
