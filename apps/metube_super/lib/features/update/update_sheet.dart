import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import 'update_state.dart';

/// The update sheet: what is new, then one prominent action according to
/// the phase.
void showUpdateSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (_) => const UpdateSheet(),
  );
}

class UpdateSheet extends ConsumerWidget {
  const UpdateSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final state = ref.watch(updateControllerProvider);
    final release = state.release;

    if (release == null) return const SizedBox.shrink();

    return ConstrainedBox(
      // **The sheet's ceiling is a fraction of the screen, not a fixed
      // number** (device round 2026-09-09): long release notes at 1.5x text
      // scale on a short screen pushed the buttons out of sight. A fraction
      // adapts to both devices.
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Padding(
        // The sheet always reaches the screen edge, and the three
        // navigation buttons eat about 48dp.
        padding: EdgeInsets.fromLTRB(
          MTSpace.xl,
          MTSpace.lg,
          MTSpace.xl,
          mtSheetBottomPad(context, MTSpace.xxl),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // **The description scrolls and the actions are pinned**: on a
            // 320x534 screen at 2.0x text scale, Android's accessibility
            // ceiling, the title, version and notes did not fit at all.
            // Scrolling the description alone keeps "download update"
            // visible instead of letting it fall off the bottom.
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.system_update_rounded, color: p.accent),
                        const SizedBox(width: MTSpace.sm),
                        Expanded(
                          child: Text(
                            l10n.updateAvailable,
                            style: text.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: MTSpace.xs),
                    Text(
                      l10n.updateVersionAvailable(release.version.toString()),
                      style: text.bodyMedium!.copyWith(color: p.ink2),
                    ),
                    if (release.sizeMb != null) ...[
                      const SizedBox(height: MTSpace.xxs),
                      Text(
                        l10n.updateSizeMb(release.sizeMb!.toStringAsFixed(1)),
                        style: text.bodySmall!.copyWith(color: p.ink3),
                      ),
                    ],
                    if (release.notes.trim().isNotEmpty) ...[
                      const SizedBox(height: MTSpace.lg),
                      MTSectionHeader(title: l10n.updateWhatsNew),
                      const SizedBox(height: MTSpace.xs),
                      Text(
                        release.notes.trim(),
                        style: text.bodySmall!.copyWith(color: p.ink2),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: MTSpace.xl),
            _Actions(state: state),
          ],
        ),
      ),
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({required this.state});

  final UpdateState state;

  /// The "install unknown apps" permission is missing: explain it, then
  /// open where it lives.
  Future<void> _askPermission(BuildContext context, WidgetRef ref) async {
    final l10n = context.mtl;
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.updateAllowInstallTitle),
        content: Text(l10n.updateAllowInstallBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.updateOpenSystemSettings),
          ),
        ],
      ),
    );
    if (go ?? false) {
      await ref.read(updateControllerProvider.notifier).openInstallSettings();
    }
  }

  Future<void> _install(BuildContext context, WidgetRef ref) async {
    final granted = await ref.read(updateControllerProvider.notifier).install();
    if (!granted && context.mounted) await _askPermission(context, ref);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final controller = ref.read(updateControllerProvider.notifier);

    if (state.phase == UpdatePhase.downloading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.updateDownloading,
            style: text.bodySmall!.copyWith(color: p.ink2),
          ),
          const SizedBox(height: MTSpace.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(MTRadius.pill),
            child: LinearProgressIndicator(
              value: state.progress,
              minHeight: 7,
              // **Both colours come from the palette explicitly**:
              // Material's default track is derived from
              // `secondaryContainer` and comes out greenish over the Wahaj
              // cream, a colour that does not exist in the identity
              // (measured on the emulator).
              backgroundColor: p.accent.withValues(alpha: 0.16),
              valueColor: AlwaysStoppedAnimation(p.accent),
            ),
          ),
          const SizedBox(height: MTSpace.sm),
          TextButton(
            onPressed: controller.cancelDownload,
            child: Text(l10n.cancel),
          ),
        ],
      );
    }

    if (state.phase == UpdatePhase.ready) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: () => _install(context, ref),
            icon: const Icon(Icons.install_mobile_rounded, size: 18),
            label: Text(l10n.updateInstall),
          ),
          const SizedBox(height: MTSpace.xs),
          Text(
            l10n.updateReady,
            textAlign: TextAlign.center,
            style: text.labelSmall!.copyWith(color: p.ink3),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.failure == UpdateFailure.download) ...[
          Text(
            l10n.updateDownloadFailed,
            style: text.bodySmall!.copyWith(color: p.err),
          ),
          const SizedBox(height: MTSpace.sm),
        ],
        if (state.failure == UpdateFailure.install) ...[
          Text(
            l10n.updateFailedToStart,
            style: text.bodySmall!.copyWith(color: p.err),
          ),
          const SizedBox(height: MTSpace.sm),
        ],
        FilledButton.icon(
          onPressed: controller.download,
          icon: const Icon(Icons.download_rounded, size: 18),
          label: Text(l10n.updateNow),
        ),
        const SizedBox(height: MTSpace.xxs),
        // **`Wrap`, not `Row`** (device matrix 2026-09-09): "later" plus
        // "skip this version" overflow a 320-point screen by 52 pixels, and
        // the yellow overflow stripe shows on the user's device, never on
        // the developer's. Wrapping moves the second one to its own line
        // instead of truncating its label.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: () {
                controller.dismiss();
                Navigator.of(context).maybePop();
              },
              child: Text(l10n.updateLater),
            ),
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                await controller.skipCurrent();
                await navigator.maybePop();
              },
              child: Text(l10n.updateSkipVersion),
            ),
          ],
        ),
      ],
    );
  }
}
