import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/hints_data.dart';
import '../../data/setup_data.dart';
import '../../shell/error_text.dart';
import '../../shell/shell_metrics.dart';
import 'setup_sections.dart';
import '../../shell/ember_dialog.dart';

/// Whether [config] reaches a MeTube server that lets it in; throws the
/// client's own reason when not. A test puts its own in.
final connectionTestProvider = Provider<Future<void> Function(ServerConfig)>(
  (ref) => (config) async {
    final client = MeTubeApiClient(config: config);
    try {
      await client.testConnection();
    } finally {
      client.close();
    }
  },
);

/// Room between the address, user name and password fields, so a floating
/// label never sits on the border of the field above it.
const double _fieldGap = MTSpace.md;

/// The setup guide, for "No server yet?".
const _serverGuide =
    'https://github.com/sagheerys/metube-mobile/blob/main/docs/SERVER-SETUP.md';

/// **The first-run setup**, opened at the first start with no
/// server and from Settings › Server: three ways to the address (a phone's
/// backup, a search of the network, typing it) that all end in the same
/// field, tested live before anything is kept.
Future<void> showSetupDialog(BuildContext context) {
  // The session's one interruption: no tip after it.
  ProviderScope.containerOf(context).read(hintsProvider.notifier).interrupted();
  return showEmberDialog<void>(
    context: context,
    builder: (_) => const _SetupDialog(),
  );
}

class _SetupDialog extends ConsumerStatefulWidget {
  const _SetupDialog();

  @override
  ConsumerState<_SetupDialog> createState() => _SetupDialogState();
}

class _SetupDialogState extends ConsumerState<_SetupDialog> {
  late final _url = TextEditingController(
    text: ref.read(serverSetupProvider)?.baseUrl ?? '',
  );
  late final _user = TextEditingController(
    text: ref.read(serverSetupProvider)?.username ?? '',
  );
  final _password = TextEditingController();
  late final _cfId = TextEditingController(
    text: ref.read(serverSetupProvider)?.access?.clientId ?? '',
  );
  late final _cfSecret = TextEditingController(
    text: ref.read(serverSetupProvider)?.access?.clientSecret ?? '',
  );
  final _passwordFocus = FocusNode();
  String? _error;
  var _testing = false;

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _password.dispose();
    _cfId.dispose();
    _cfSecret.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _use(String url, {bool needsPassword = false}) {
    setState(() {
      _url.text = url;
      _error = null;
    });
    if (needsPassword) _passwordFocus.requestFocus();
  }

  /// An http:// address that is not on the home network sends the
  /// password as plain text across the internet.
  bool get _plainPassword {
    final uri = Uri.tryParse(_url.text.trim());
    if (uri == null || uri.scheme != 'http' || _password.text.isEmpty) {
      return false;
    }
    final host = uri.host;
    final home = RegExp(r'^(10\.|192\.168\.|127\.|172\.(1[6-9]|2\d|3[01])\.)')
        .hasMatch(host);
    return !home && host.contains('.') && !host.endsWith('.local');
  }

  Future<void> _connect() async {
    final l = context.mtl;
    final url = _url.text.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(url);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme)) {
      setState(() => _error = l.serverUrlRequired);
      return;
    }
    final access = CloudflareAccess.typed(_cfId.text, _cfSecret.text);
    // Both values or neither: one alone only earns a rejection that looks
    // like a wrong address.
    if (access != null && !access.isComplete) {
      setState(() => _error = l.cloudflareBothRequired);
      return;
    }
    final config = ServerConfig(
      baseUrl: url,
      username: _user.text.trim().isEmpty ? null : _user.text.trim(),
      password: _password.text.isEmpty ? null : _password.text,
      access: access,
    );
    setState(() {
      _testing = true;
      _error = null;
    });
    try {
      await ref.read(connectionTestProvider)(config);
    } on Object catch (e) {
      if (mounted) {
        setState(() {
          _testing = false;
          _error = errorText(l, e);
        });
      }
      return;
    }
    await ref.read(serverSetupProvider.notifier).save(config);
    if (!mounted) return;
    Navigator.of(context).pop();
    showMTNotice(
      context,
      message: l.connectionSuccessful,
      kind: MTNoticeKind.done,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return AlertDialog(
      title: Text(l.desktopSetupTitle),
      content: SizedBox(
        width: EmberShellSize.addDialog,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ImportSection(onAddress: _use),
              SearchSection(
                onFound: (url, locked) => _use(url, needsPassword: locked),
              ),
              SetupSection(
                title: l.desktopSetupEnter,
                hint: l.serverUrlHint,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _url,
                      keyboardType: TextInputType.url,
                      textDirection: TextDirection.ltr,
                      onChanged: (_) => setState(() => _error = null),
                      decoration: InputDecoration(labelText: l.serverUrl),
                    ),
                    const SizedBox(height: _fieldGap),
                    TextField(
                      controller: _user,
                      textDirection: TextDirection.ltr,
                      decoration: InputDecoration(labelText: l.username),
                    ),
                    const SizedBox(height: _fieldGap),
                    TextField(
                      controller: _password,
                      focusNode: _passwordFocus,
                      obscureText: true,
                      textDirection: TextDirection.ltr,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => unawaited(_connect()),
                      decoration: InputDecoration(labelText: l.password),
                    ),
                    const SizedBox(height: _fieldGap),
                    MTAccessTokenFields(
                      clientId: _cfId,
                      clientSecret: _cfSecret,
                      gap: _fieldGap,
                    ),
                    if (_plainPassword)
                      Padding(
                        padding: const EdgeInsets.only(top: MTSpace.xs),
                        child: Text(
                          l.desktopSetupHttpWarning,
                          style: text.labelSmall?.copyWith(color: p.err),
                        ),
                      ),
                    if (_error case final error?)
                      Padding(
                        padding: const EdgeInsets.only(top: MTSpace.xs),
                        child: Text(
                          error,
                          style: text.bodySmall?.copyWith(color: p.err),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        MTLinkButton(
          label: l.desktopSetupNoServer,
          onPressed: () => unawaited(
            launchUrl(
              Uri.parse(_serverGuide),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.desktopSetupLater),
        ),
        FilledButton(
          onPressed: _testing ? null : () => unawaited(_connect()),
          child: Text(l.desktopSetupConnect),
        ),
      ],
    );
  }
}
