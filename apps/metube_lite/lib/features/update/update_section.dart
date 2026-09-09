import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import 'update_sheet.dart';
import 'update_state.dart';

/// The "updates" section in settings, added as one widget so the settings
/// screen stays under the 400-line limit.
class UpdateSection extends ConsumerWidget {
  const UpdateSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final state = ref.watch(updateControllerProvider);
    final controller = ref.read(updateControllerProvider.notifier);
    final hasUpdate = state.release != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MTSectionHeader(title: l10n.updates),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            hasUpdate ? Icons.system_update_rounded : Icons.update_rounded,
            // **The accent colour when an update exists**, read from the
            // palette so
            // Super's ember never leaks into Lite's petrol bay.
            color: hasUpdate ? p.accent : p.ink2,
          ),
          title: Text(
            hasUpdate ? l10n.updateAvailable : l10n.checkForUpdates,
            style: hasUpdate
                ? text.bodyLarge!.copyWith(
                    color: p.accent,
                    fontWeight: FontWeight.w700,
                  )
                : null,
          ),
          subtitle: Text(
            _subtitle(context, state),
            style: text.bodySmall!.copyWith(color: p.ink3),
          ),
          trailing: state.phase == UpdatePhase.checking
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(
                  hasUpdate
                      ? Icons.chevron_right_rounded
                      : Icons.refresh_rounded,
                ),
          onTap: state.busy
              ? null
              : () async {
                  if (hasUpdate) {
                    showUpdateSheet(context);
                    return;
                  }
                  await controller.checkNow();
                  // After a manual check: an update opens the sheet
                  // immediately, and its
                  // absence is said plainly. Silence looks like a fault.
                  if (!context.mounted) return;
                  final after = ref.read(updateControllerProvider);
                  if (after.release != null) {
                    showUpdateSheet(context);
                  } else if (after.failure == UpdateFailure.check) {
                    showMTSnack(
                      context,
                      l10n.updateCheckFailed,
                      type: MTSnackType.error,
                    );
                  } else if (after.upToDate) {
                    showMTSnack(
                      context,
                      l10n.updateUpToDate,
                      type: MTSnackType.success,
                    );
                  }
                },
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.autoCheckUpdates, style: text.bodyMedium),
          subtitle: Text(l10n.autoCheckUpdatesHelp, style: text.bodySmall),
          value: state.autoCheck,
          onChanged: controller.setAutoCheck,
        ),
      ],
    );
  }

  String _subtitle(BuildContext context, UpdateState state) {
    final l10n = context.mtl;
    final release = state.release;
    if (release != null) return release.version.toString();
    if (state.phase == UpdatePhase.checking) return l10n.updateChecking;
    final at = state.checkedAt;
    return l10n.lastCheckedAt(
      at == null ? l10n.updateNever : mtTimeAgo(context, at),
    );
  }
}
