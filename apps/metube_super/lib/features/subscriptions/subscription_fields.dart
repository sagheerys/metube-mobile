import 'package:flutter/material.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../settings/widgets/help_button.dart';

/// The quality a subscription downloads at, asked once when following.
///
/// **Said before the choice, because it cannot be undone after it**
/// (2026-09-25): the server keeps the quality it was given and offers no
/// way to change it. The help is conditional on purpose — "best" is AV1 at
/// 4K, smooth on a phone that decodes AV1 in hardware and choppy on one
/// that does not, and a warning for everyone would push the first kind down
/// to 1080p for nothing. Telling the two apart would need the device's
/// decoders queried, which this sheet does not do yet.
class SubscriptionQualityField extends StatelessWidget {
  const SubscriptionQualityField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final Quality value;
  final ValueChanged<Quality> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: DropdownMenu<Quality>(
            initialSelection: value,
            label: Text(l10n.subscriptionQuality),
            helperText: l10n.subscriptionQualityNote,
            expandedInsets: EdgeInsets.zero,
            onSelected: (picked) => onChanged(picked ?? Quality.best),
            dropdownMenuEntries: [
              DropdownMenuEntry(value: Quality.best, label: l10n.qualityBest),
              DropdownMenuEntry(value: Quality.q1080, label: l10n.quality1080),
              DropdownMenuEntry(value: Quality.q720, label: l10n.quality720),
              DropdownMenuEntry(value: Quality.q480, label: l10n.quality480),
              DropdownMenuEntry(value: Quality.audio, label: l10n.audioOnly),
            ],
          ),
        ),
        HelpButton(
          title: l10n.subscriptionQuality,
          body: l10n.subscriptionQualityHelp,
        ),
      ],
    );
  }
}

/// **"Save in its own folder"**, off unless the subscription already has
/// one. A choice, not a rule: most people never open the server's folders,
/// and those who browse them over the network share get the one order the
/// app's tags cannot give them there.
///
/// The name may be left empty, and the channel's own name is used.
class SubscriptionFolderField extends StatelessWidget {
  const SubscriptionFolderField({
    super.key,
    required this.enabled,
    required this.controller,
    required this.onToggle,
  });

  final bool enabled;
  final TextEditingController controller;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: enabled,
          onChanged: onToggle,
          title: Text(l10n.ownFolder),
          subtitle: Text(l10n.ownFolderNote),
        ),
        if (enabled)
          TextField(
            controller: controller,
            decoration: InputDecoration(
              labelText: l10n.folderName,
              hintText: l10n.folderNameHint,
              prefixIcon: const Icon(Icons.folder_rounded),
            ),
          ),
      ],
    );
  }
}
