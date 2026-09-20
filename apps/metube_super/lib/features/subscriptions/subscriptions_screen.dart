import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../shared/error_text.dart';
import 'subscription_sheet.dart';
import 'subscriptions_providers.dart';
import 'widgets/subscription_card.dart';

/// **Channels the server follows** (م-71, Super only).
///
/// Nothing here runs on the phone. MeTube keeps the list, checks it on its
/// own schedule and downloads what is new; this screen is a remote control
/// for that list, and whatever the server fetches reaches the library
/// through `/history` like any other download.
class SubscriptionsScreen extends ConsumerWidget {
  const SubscriptionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.mtl;
    final state = ref.watch(subscriptionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.subscriptions),
        actions: [
          if (state.valueOrNull?.supported ?? false) ...[
            IconButton(
              tooltip: l10n.checkNow,
              onPressed: () => _checkAll(context, ref),
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ],
      ),
      // **The identity's own button**, not Material's: the library's "add
      // link" is a solid accent block, and a pale Material FAB beside it
      // would read as a different app.
      floatingActionButton: (state.valueOrNull?.supported ?? false)
          ? MTFab(
              label: l10n.followChannel,
              icon: Icons.add_link_rounded,
              onPressed: () => showSubscriptionSheet(context, ref),
            )
          : null,
      body: state.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(MTSpace.pagePad),
          child: MTEmptyState(
            icon: Icons.error_outline_rounded,
            title: l10n.failed,
            message: errorText(l10n, e),
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(subscriptionsProvider),
          ),
        ),
        data: (data) => data.supported
            ? _list(context, ref, data.sorted)
            : _unsupported(context),
      ),
    );
  }

  /// **The one case that is not an error and not an empty list**: a MeTube
  /// older than subscriptions. Saying so, with what to do about it, is
  /// worth more than a settings entry that quietly disappears.
  Widget _unsupported(BuildContext context) {
    final l10n = context.mtl;
    return Padding(
      padding: const EdgeInsets.all(MTSpace.pagePad),
      child: MTEmptyState(
        icon: Icons.update_rounded,
        title: l10n.subscriptionsUnsupported,
        message: l10n.subscriptionsUnsupportedBody,
      ),
    );
  }

  Widget _list(
    BuildContext context,
    WidgetRef ref,
    List<ChannelSubscription> subs,
  ) {
    final l10n = context.mtl;
    if (subs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(MTSpace.pagePad),
        child: MTEmptyState(
          icon: Icons.rss_feed_rounded,
          title: l10n.subscriptionsEmpty,
          message: l10n.subscriptionsEmptyBody,
          actionLabel: l10n.followChannel,
          onAction: () => showSubscriptionSheet(context, ref),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(subscriptionsProvider),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          MTSpace.pagePad,
          MTSpace.md,
          MTSpace.pagePad,
          // Clear of the floating button, which would otherwise sit on the
          // last card's menu.
          MTSpace.xxl * 2,
        ),
        children: [
          for (final sub in subs)
            SubscriptionCard(
              subscription: sub,
              onToggle: (enabled) =>
                  _run(context, ref, (c) => c.setEnabled(sub, enabled)),
              onEdit: () => showSubscriptionSheet(context, ref, editing: sub),
              onCheckNow: () => _checkAll(context, ref, only: sub),
              onUnfollow: () => _confirmUnfollow(context, ref, sub),
            ),
        ],
      ),
    );
  }

  /// A check walks the channel with yt-dlp, which is slow enough that the
  /// user is told it started rather than left watching a spinner.
  void _checkAll(
    BuildContext context,
    WidgetRef ref, {
    ChannelSubscription? only,
  }) {
    showMTSnack(context, context.mtl.checkQueued, type: MTSnackType.info);
    _run(context, ref, (c) => c.checkNow(only: only));
  }

  /// **Unfollowing is confirmed and pausing is not**, because only one of
  /// them destroys something: the server's memory of what it has already
  /// seen, which cannot be rebuilt.
  Future<void> _confirmUnfollow(
    BuildContext context,
    WidgetRef ref,
    ChannelSubscription sub,
  ) async {
    final l10n = context.mtl;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.unfollowConfirm(mtName(sub.name))),
        content: Text(l10n.unfollowConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.unfollow),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    _run(context, ref, (c) => c.unfollow(sub));
  }

  /// Every action goes through here so a server that refuses says why,
  /// instead of leaving a switch that flicks back with no explanation.
  void _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function(SubscriptionsController) action,
  ) {
    final l10n = context.mtl;
    // Captured now: the action outlives the frame, and reading the
    // messenger from a dead context afterwards throws.
    final messenger = ScaffoldMessenger.of(context);
    action(ref.read(subscriptionsControllerProvider)).catchError((Object e) {
      messenger.showSnackBar(SnackBar(content: Text(errorText(l10n, e))));
    });
  }
}
