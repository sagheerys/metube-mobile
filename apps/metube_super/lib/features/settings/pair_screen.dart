import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../di.dart';
import 'settings_state.dart';

/// **What the code will say**, built where a test can reach it: the QR
/// widget keeps its data private, so asserting on the picture is not
/// possible and asserting on this is.
@visibleForTesting
PairingPayload pairingPayloadFor(SuperSettings settings, String url) =>
    PairingPayload(
      url: url,
      username: settings.username,
      password: settings.password,
    );

/// **Setting up someone else's phone** (م-74).
///
/// The alternative is reading `http://192.168.2.245:8086` aloud to someone
/// who has never typed a port number, and a password after it. This draws
/// it once and their camera does the typing.
///
/// **Super draws; it never scans.** The camera belongs in Lite, where the
/// family's phones are, and keeping it out of the owner's app is a
/// permission not requested.
class PairScreen extends ConsumerStatefulWidget {
  const PairScreen({super.key});

  @override
  ConsumerState<PairScreen> createState() => _PairScreenState();
}

class _PairScreenState extends ConsumerState<PairScreen> {
  String? _chosen;

  /// **Covered until asked for.** The code is a password in a picture: it
  /// should not be sitting on a screen that happens to be face up on a
  /// table, and it should not appear in a screenshot taken for some other
  /// reason.
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final settings = ref.watch(settingsProvider);
    final addresses = settings.candidateUrls;
    final url = _chosen ?? settings.activeUrl ?? addresses.firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.pairTitle)),
      body: url == null
          ? Padding(
              padding: const EdgeInsets.all(MTSpace.pagePad),
              child: MTEmptyState(
                icon: Icons.cloud_off_rounded,
                title: l10n.noServerTitle,
                message: l10n.pairNeedsServer,
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                MTSpace.pagePad,
                MTSpace.md,
                MTSpace.pagePad,
                MTSpace.xxl,
              ),
              children: [
                Text(
                  l10n.pairHowTo,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: MTSpace.lg),
                _code(context, settings, url),
                const SizedBox(height: MTSpace.lg),
                if (addresses.length > 1) ...[
                  Text(
                    l10n.pairWhichAddress,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: MTSpace.xs),
                  RadioGroup<String>(
                    groupValue: url,
                    onChanged: (value) => setState(() {
                      _chosen = value;
                      // A new address means a new code; showing the old one
                      // for even a frame would pair the wrong phone.
                      _revealed = false;
                    }),
                    child: Column(
                      children: [
                        for (final address in addresses)
                          RadioListTile<String>(
                            contentPadding: EdgeInsets.zero,
                            value: address,
                            title: Text(
                              address,
                              textDirection: TextDirection.ltr,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: MTSpace.md),
                ],
                // **The one thing that ruins this quietly**: a code made
                // from the house address works in the living room and
                // fails in the street, with nothing to explain why.
                if (PairingPayload(url: url).isPrivateAddress)
                  _note(
                    context,
                    Icons.home_rounded,
                    l10n.pairLocalOnly,
                    p.ink3,
                  ),
                const SizedBox(height: MTSpace.sm),
                _note(
                  context,
                  Icons.lock_outline_rounded,
                  settings.password?.isNotEmpty ?? false
                      ? l10n.pairCarriesPassword
                      : l10n.pairNoPassword,
                  p.err,
                ),
              ],
            ),
    );
  }

  Widget _code(BuildContext context, SuperSettings settings, String url) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;
    final payload = pairingPayloadFor(settings, url);

    return Center(
      child: Container(
        padding: const EdgeInsets.all(MTSpace.lg),
        decoration: BoxDecoration(
          // **Always light behind the code**, whatever the theme: a QR is
          // read by contrast, and a scanner pointed at cream-on-espresso
          // hunts for a while before it gives up.
          color: Colors.white,
          borderRadius: BorderRadius.circular(MTRadius.card),
          border: Border.all(color: p.line),
        ),
        child: SizedBox(
          width: 240,
          height: 240,
          child: _revealed
              ? QrImageView(
                  // The address is on the widget so a test can say which
                  // one is drawn; the password never leaves `data`.
                  key: ValueKey(url),
                  data: payload.encode(),
                  version: QrVersions.auto,
                  gapless: true,
                  backgroundColor: Colors.white,
                  // Black on white regardless of the palette, for the same
                  // reason as the background.
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.black,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Colors.black,
                  ),
                )
              : Center(
                  child: FilledButton.icon(
                    onPressed: () => setState(() => _revealed = true),
                    icon: const Icon(Icons.qr_code_2_rounded),
                    label: Text(l10n.pairShowCode),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _note(BuildContext context, IconData icon, String text, Color color) =>
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: MTSpace.xs),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: color),
            ),
          ),
        ],
      );
}
