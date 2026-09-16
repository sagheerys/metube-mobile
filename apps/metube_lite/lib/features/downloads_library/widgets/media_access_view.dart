import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_ui/mt_ui.dart';

import '../library_providers.dart';
import '../media_access.dart';

/// The library's screen when Android is holding the folder shut: a sentence
/// saying why, and the button that asks. **The permission dialog is the only
/// exit most users will find** — before this, the screen showed
/// `PathAccessException ... errno = 13` and a Retry that retried nothing.
class MediaAccessView extends ConsumerStatefulWidget {
  const MediaAccessView({super.key});

  @override
  ConsumerState<MediaAccessView> createState() => _MediaAccessViewState();
}

class _MediaAccessViewState extends ConsumerState<MediaAccessView> {
  bool _blocked = false;
  bool _busy = false;

  Future<void> _act() async {
    if (_busy) return;
    setState(() => _busy = true);
    final gate = ref.read(mediaAccessGateProvider);
    try {
      if (_blocked) {
        await gate.openSettings();
        // Coming back from settings, the folder may read now.
        ref.invalidate(localMediaProvider);
        return;
      }
      final result = await gate.ensure();
      if (!mounted) return;
      if (result == MediaAccess.granted) {
        ref.invalidate(localMediaProvider);
      } else if (result == MediaAccess.blocked) {
        setState(() => _blocked = true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = MTLocalizations.of(context);
    return MTEmptyState(
      icon: Icons.perm_media_outlined,
      title: l10n.mediaAccessTitle,
      message: _blocked
          ? l10n.mediaAccessBlockedMessage
          : l10n.mediaAccessMessage,
      actionLabel: _blocked
          ? l10n.mediaAccessOpenSettings
          : l10n.mediaAccessGrant,
      onAction: _busy ? null : _act,
    );
  }
}
