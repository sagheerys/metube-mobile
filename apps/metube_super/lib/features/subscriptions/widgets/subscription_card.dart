import 'package:flutter/material.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// One followed channel.
///
/// The card answers, in order, the three things someone looks for: is it
/// running, when was it last looked at, and did the last look fail. The
/// switch is the primary control because pausing is the safe retreat and
/// unfollowing is not — unfollowing throws away what the server has seen.
class SubscriptionCard extends StatelessWidget {
  const SubscriptionCard({
    super.key,
    required this.subscription,
    required this.onToggle,
    required this.onEdit,
    required this.onCheckNow,
    required this.onUnfollow,
  });

  final ChannelSubscription subscription;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onCheckNow;
  final VoidCallback onUnfollow;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    final sub = subscription;
    // A paused row is dimmed rather than hidden: it is still a channel the
    // user chose, and it comes back with one tap.
    final dim = sub.enabled ? 1.0 : 0.55;

    return Container(
      margin: const EdgeInsets.only(bottom: MTSpace.md),
      padding: const EdgeInsets.all(MTSpace.md),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(MTRadius.card),
        border: Border.all(color: sub.hasError ? p.err : p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Opacity(
                  opacity: dim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sub.name,
                        style: text.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub.url,
                        // The link is Latin whatever the interface
                        // language, and reads backwards without this.
                        textDirection: TextDirection.ltr,
                        style: text.bodySmall?.copyWith(color: p.ink3),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              // A switch says nothing on its own about what it governs,
              // so the label a screen reader reads is put around it.
              Semantics(
                label: sub.enabled
                    ? l10n.pauseSubscription
                    : l10n.resumeSubscription,
                child: Switch(value: sub.enabled, onChanged: onToggle),
              ),
              _menu(context, l10n),
            ],
          ),
          const SizedBox(height: MTSpace.sm),
          Opacity(
            opacity: dim,
            child: Wrap(
              spacing: MTSpace.sm,
              runSpacing: MTSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _chip(context, Icons.schedule_rounded, _intervalLabel(l10n)),
                if (sub.quality case final quality?)
                  _chip(context, Icons.high_quality_rounded, quality),
                if (sub.titleRegex case final filter?)
                  _chip(context, Icons.filter_alt_outlined, filter),
                if (!sub.enabled)
                  _chip(context, Icons.pause_rounded, l10n.subscriptionPaused),
              ],
            ),
          ),
          const SizedBox(height: MTSpace.sm),
          Opacity(
            opacity: dim,
            child: Text(
              '${_lastCheckedLabel(context, l10n)} · '
              '${l10n.knownVideos(sub.seenCount)}',
              style: text.bodySmall?.copyWith(color: p.ink3),
            ),
          ),
          // **The server's own words, shown verbatim.** A channel that was
          // renamed, went private or hit a login wall fails here and
          // nowhere else, and paraphrasing it would hide the one clue.
          if (sub.hasError) ...[
            const SizedBox(height: MTSpace.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline_rounded, size: 16, color: p.err),
                const SizedBox(width: MTSpace.xs),
                Expanded(
                  child: Text(
                    sub.error!,
                    style: text.bodySmall?.copyWith(color: p.err),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _menu(BuildContext context, MTLocalizations l10n) =>
      PopupMenuButton<_CardAction>(
        icon: const Icon(Icons.more_vert_rounded),
        onSelected: (action) => switch (action) {
          _CardAction.check => onCheckNow(),
          _CardAction.edit => onEdit(),
          _CardAction.unfollow => onUnfollow(),
        },
        itemBuilder: (_) => [
          PopupMenuItem(
            value: _CardAction.check,
            child: _MenuRow(icon: Icons.refresh_rounded, label: l10n.checkNow),
          ),
          PopupMenuItem(
            value: _CardAction.edit,
            child: _MenuRow(icon: Icons.edit_outlined, label: l10n.rename),
          ),
          PopupMenuItem(
            value: _CardAction.unfollow,
            child: _MenuRow(icon: Icons.link_off_rounded, label: l10n.unfollow),
          ),
        ],
      );

  Widget _chip(BuildContext context, IconData icon, String label) {
    final p = MTThemeX.of(context).palette;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MTSpace.sm,
        vertical: MTSpace.xs,
      ),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: BorderRadius.circular(MTRadius.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: p.ink3),
          const SizedBox(width: MTSpace.xs),
          // A filter can be any regular expression the user typed, so it is
          // bounded rather than allowed to push the row off the screen.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 160),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall
                  ?.copyWith(color: p.ink),
            ),
          ),
        ],
      ),
    );
  }

  String _intervalLabel(MTLocalizations l10n) {
    final minutes = subscription.checkIntervalMinutes;
    if (minutes < 60) return l10n.every30Minutes;
    return l10n.everyHours(minutes ~/ 60);
  }

  String _lastCheckedLabel(BuildContext context, MTLocalizations l10n) {
    final at = subscription.lastChecked;
    if (at == null) return l10n.neverChecked;
    return l10n.lastCheckedAt(mtTimeAgo(context, at));
  }
}

enum _CardAction { check, edit, unfollow }

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: MTSpace.sm),
      Text(label),
    ],
  );
}
