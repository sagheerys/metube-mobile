import 'package:flutter/material.dart';

import '../icons/mt_icon.dart';
import '../icons/mt_icons.dart';
import '../l10n/l10n.dart';
import '../theme/mt_theme.dart';
import '../tokens/tokens.dart';
import '../wahaj/mt_link_button.dart';

/// The optional Cloudflare Access service token, under the server's own
/// sign-in fields.
///
/// **Folded behind one link until it is wanted**: almost no server sits
/// behind Access, so everyone else sees one quiet line instead of two
/// fields that look mandatory. It opens by itself when a pair is already
/// stored, so the person who set one can see it.
///
/// The fields only hold text. Checking that both are filled, testing and
/// storing them is the screen's job, as for the password.
class MTAccessTokenFields extends StatefulWidget {
  const MTAccessTokenFields({
    super.key,
    required this.clientId,
    required this.clientSecret,
    this.gap = MTSpace.md,
  });

  final TextEditingController clientId;
  final TextEditingController clientSecret;

  /// The room between the fields, matching the screen's other fields.
  final double gap;

  @override
  State<MTAccessTokenFields> createState() => _MTAccessTokenFieldsState();
}

class _MTAccessTokenFieldsState extends State<MTAccessTokenFields> {
  late bool _open =
      widget.clientId.text.isNotEmpty || widget.clientSecret.text.isNotEmpty;
  bool _showSecret = false;

  @override
  Widget build(BuildContext context) {
    final l = context.mtl;
    final p = MTThemeX.of(context).palette;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: MTLinkButton(
            key: const ValueKey('cloudflare-access'),
            label: l.cloudflareAccess,
            icon: _open ? MTIcons.chevronUp : MTIcons.chevronDown,
            onPressed: () => setState(() => _open = !_open),
          ),
        ),
        if (_open) ...[
          Text(
            l.cloudflareAccessHelp,
            style: text.bodySmall?.copyWith(color: p.ink3),
          ),
          SizedBox(height: widget.gap),
          TextField(
            controller: widget.clientId,
            textDirection: TextDirection.ltr,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: l.cloudflareClientId),
          ),
          SizedBox(height: widget.gap),
          TextField(
            controller: widget.clientSecret,
            textDirection: TextDirection.ltr,
            obscureText: !_showSecret,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: l.cloudflareClientSecret,
              // A pasted secret is long and unreadable as dots; showing it
              // is how a person checks the paste took the whole value.
              suffixIcon: IconButton(
                tooltip: _showSecret
                    ? l.cloudflareHideSecret
                    : l.cloudflareShowSecret,
                icon: MTIcon(
                  _showSecret ? MTIcons.unlock : MTIcons.lock,
                  size: 18,
                ),
                onPressed: () => setState(() => _showSecret = !_showSecret),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
