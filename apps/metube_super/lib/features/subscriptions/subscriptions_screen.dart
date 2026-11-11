import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:go_router/go_router.dart';

import '../settings/settings_sections.dart';
import '../settings/widgets/settings_fields.dart';
import '../shared/error_text.dart';
import 'channel_actions.dart';
import 'subscription_sheet.dart';
import 'subscriptions_providers.dart';
import 'channel_match.dart';
import 'widgets/channel_row.dart';

/// **Channels the server follows** (Super only).
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
              onPressed: () => checkSubscriptions(context, ref),
              icon: const MTIcon(MTIcons.refresh),
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
              icon: MTIcons.addlink,
              onPressed: () => showSubscriptionSheet(context, ref),
            )
          : null,
      body: MTReadableWidth(
        child: state.when(
          loading: () => const Center(child: MTSpinner()),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(MTSpace.pagePad),
            child: MTEmptyState(
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
    final match = ref.watch(channelMatchProvider).valueOrNull;
    if (subs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(MTSpace.pagePad),
        child: MTEmptyState(
          title: l10n.subscriptionsEmpty,
          message: l10n.subscriptionsEmptyBody,
          actionLabel: l10n.followChannel,
          onAction: () => showSubscriptionSheet(context, ref),
        ),
      );
    }
    return MTPullRefresh(
      onRefresh: () async => ref.invalidate(subscriptionsProvider),
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          MTSpace.pagePad,
          MTSpace.md,
          MTSpace.pagePad,
          // Clear of the floating button, which would otherwise sit on the
          // last card's menu.
          mtFabClearance(context),
        ),
        children: [
          // Moved here from the settings' preferences: it is about these
          // channels and nothing else.
          const ArrivalsSwitch(),
          const SizedBox(height: MTSpace.sm),
          // Pausing sends a row to the end of the list: it travels there
          // rather than vanishing from under the finger.
          MTReorderMotion(
            children: [
              for (final sub in subs)
                ChannelRow(
                  key: ValueKey(sub.id),
                  sub: sub,
                  stats: match?.stats[sub.id],
                  onOpen: () => context.push(
                    '${SettingsPane.subscriptions.route}/channel/${sub.id}',
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
