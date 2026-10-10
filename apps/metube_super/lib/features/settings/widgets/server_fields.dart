import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../../di.dart';
import '../../shared/error_report.dart';
import 'help_button.dart';
import 'server_status_card.dart';

/// The server's address and sign-in, tested before they are saved. One
/// widget for the phone's settings page and the tablet's server pane.
class ServerFields extends ConsumerStatefulWidget {
  const ServerFields({super.key, this.showHeader = true});

  /// False under a pane title that already names the section.
  final bool showHeader;

  @override
  ConsumerState<ServerFields> createState() => _ServerFieldsState();
}

class _ServerFieldsState extends ConsumerState<ServerFields> {
  late final _urlController = TextEditingController(
    text: ref.read(settingsProvider).activeUrl ?? '',
  );
  late final _userController = TextEditingController(
    text: ref.read(settingsProvider).username ?? '',
  );
  late final _passController = TextEditingController(
    text: ref.read(settingsProvider).password ?? '',
  );
  bool _testing = false;

  @override
  void dispose() {
    _urlController.dispose();
    _userController.dispose();
    _passController.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    final l10n = context.mtl;
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      showMTSnack(context, l10n.serverUrlRequired, type: MTSnackType.error);
      return;
    }
    setState(() => _testing = true);
    try {
      // Rule 1: no silent saving of a broken setting. Test first, with
      // classified messages.
      await ref
          .read(settingsProvider.notifier)
          .saveServer(
            url: url,
            username: _userController.text.trim(),
            password: _passController.text,
          );
      ref.invalidate(serverStatusProvider);
      if (mounted) {
        showMTSnack(
          context,
          l10n.connectionSuccessful,
          type: MTSnackType.success,
        );
      }
    } on MTApiException catch (e) {
      if (mounted) {
        showErrorSnack(context, ref, e, tag: 'server');
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showHeader) ...[
          MTSectionHeader(title: l10n.serverConfiguration),
          const SizedBox(height: MTSpace.md),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _urlController,
                keyboardType: TextInputType.url,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.serverUrl,
                  hintText: l10n.serverUrlHint,
                ),
              ),
            ),
            HelpButton(
              title: l10n.serverUrlHelpTitle,
              body: l10n.serverUrlHelpBody,
            ),
          ],
        ),
        const SizedBox(height: MTSpace.md),
        // **A gap exactly as wide as the help button** (review 2026-09-05):
        // without it the username field alone reached the edge, so three
        // consecutive fields had different right edges.
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _userController,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  labelText: l10n.username,
                  // **Said in the open, not behind the help button** (field
                  // report 2026-09-19): the two fields look mandatory, so
                  // whoever runs an open server invents a username to fill
                  // them. The text already existed; it was only ever shown
                  // to someone who thought to press "?", which is exactly
                  // the person who did not need it.
                  helperText: l10n.authHelper,
                  helperMaxLines: 2,
                ),
              ),
            ),
            const HelpButtonGap(),
          ],
        ),
        const SizedBox(height: MTSpace.md),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _passController,
                obscureText: true,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(labelText: l10n.password),
              ),
            ),
            HelpButton(title: l10n.authentication, body: l10n.authHelper),
          ],
        ),
        const SizedBox(height: MTSpace.lg),
        FilledButton.icon(
          onPressed: _testing ? null : _testAndSave,
          icon: _testing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.wifi_tethering_rounded, size: 18),
          label: Text(_testing ? l10n.testingConnection : l10n.saveSettings),
        ),
      ],
    );
  }
}
