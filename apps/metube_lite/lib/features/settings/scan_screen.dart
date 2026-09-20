import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import '../../di.dart';
import '../shared/error_text.dart';

/// **Reading the setup code the owner shows** (م-74, Lite only).
///
/// This is the whole point of Lite's promise: the family never has to
/// know the server exists. Before this, someone still had to be told an
/// address and a password and type both without a mistake.
///
/// **The connection is tested before anything is saved**, exactly as the
/// manual form does (rule 1): a code from the wrong address must fail
/// here, in front of the person who scanned it, rather than become a
/// setting that breaks every download afterwards.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );

  /// **One code is acted on, ever.** The camera fires the same barcode
  /// many times a second, and without this the connection test runs
  /// dozens of times over and the screen pops more than once.
  bool _handled = false;
  String? _error;

  /// **The reader is not in the app; Play services fetches it on first
  /// use** (measured on the emulator 2026-09-20). Until it arrives every
  /// frame throws `Waiting for the barcode module to be downloaded`, and
  /// without this the user watches a blank camera with nothing to read
  /// and no idea anything is happening.
  bool _preparing = false;

  /// Detection errors arrive once per frame, so the state is set once and
  /// the log is written once.
  bool _notedDetectError = false;

  void _onDetectError(Object error, StackTrace stackTrace) {
    final text = error.toString().toLowerCase();
    final downloading =
        text.contains('barcode module') || text.contains('downloaded');
    if (_preparing == downloading && _notedDetectError) return;
    _notedDetectError = true;
    if (!mounted) return;
    setState(() {
      _preparing = downloading;
      // Anything that is not the module arriving is a real failure, and
      // the manual form is the way out of it.
      _error = downloading ? null : context.mtl.scanNoCameraBody;
    });
    unawaited(
      ref.read(loggerProvider).log('scan detect error: $error', tag: 'scan'),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handled) return;
    final raw = capture.barcodes
        .map((barcode) => barcode.rawValue)
        .firstWhere(
          (value) => value != null && value.isNotEmpty,
          orElse: () => null,
        );
    if (raw == null) return;

    // A code was read, so whatever the module was doing, it is ready.
    if (_preparing && mounted) setState(() => _preparing = false);

    final payload = PairingPayload.decode(raw);
    if (payload == null) {
      // **Not ours, and said so.** A camera reads every code it is pointed
      // at; "that is not a MeTube code" is more use than silence, and the
      // scanner keeps running so the next one can be tried.
      if (mounted) setState(() => _error = context.mtl.scanNotOurCode);
      return;
    }

    _handled = true;
    await _controller.stop();
    if (!mounted) return;
    setState(() => _error = null);
    await _apply(payload);
  }

  Future<void> _apply(PairingPayload payload) async {
    final l10n = context.mtl;
    try {
      await ref
          .read(settingsProvider.notifier)
          .saveServer(
            url: payload.url,
            username: payload.username,
            password: payload.password,
          );
      if (!mounted) return;
      showMTSnack(
        context,
        l10n.connectionSuccessful,
        type: MTSnackType.success,
      );
      context.go('/settings');
    } on Object catch (e) {
      if (!mounted) return;
      // The code was readable and the server was not reachable — two very
      // different problems, and the second one is worth another try from
      // the same screen.
      setState(() {
        _handled = false;
        _error = errorText(l10n, e);
      });
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.mtl;
    final p = MTThemeX.of(context).palette;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.scanTitle)),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  onDetectError: _onDetectError,
                  errorBuilder: (context, error) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(MTSpace.pagePad),
                      child: MTEmptyState(
                        icon: Icons.no_photography_outlined,
                        title: l10n.scanNoCamera,
                        message: l10n.scanNoCameraBody,
                      ),
                    ),
                  ),
                ),
                // A window to aim through: without one people hold the
                // phone too close and the code never resolves.
                IgnorePointer(
                  child: Center(
                    child: Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        border: Border.all(color: p.accent, width: 3),
                        borderRadius: BorderRadius.circular(MTRadius.card),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            color: p.card,
            padding: EdgeInsets.fromLTRB(
              MTSpace.pagePad,
              MTSpace.md,
              MTSpace.pagePad,
              mtSheetBottomPad(context, MTSpace.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_preparing)
                  Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: MTSpace.sm),
                      Expanded(
                        child: Text(
                          l10n.scanPreparing,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    l10n.scanHowTo,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                if (_error case final message?) ...[
                  const SizedBox(height: MTSpace.sm),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.error_outline_rounded, size: 16, color: p.err),
                      const SizedBox(width: MTSpace.xs),
                      Expanded(
                        child: Text(
                          message,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: p.err),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
