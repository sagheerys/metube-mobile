import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/features/shared/error_report.dart';
import 'package:metube_lite/features/shared/error_text.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// The log held in memory, so the test needs no disk.
class _Lines extends MTLogger {
  _Lines() : super(filePath: '');

  final lines = <String>[];

  @override
  Future<void> log(
    String message, {
    LogLevel level = LogLevel.info,
    String? tag,
  }) async => lines.add(message);
}

/// Owner's request 2026-10-15: every error that shows, and every error
/// nobody caught, is in the diagnostic log.
void main() {
  testWidgets('error snack bars and framework errors reach the log', (
    tester,
  ) async {
    final testHandler = FlutterError.onError;
    // Kept from the test framework, which would fail the test on the
    // error raised on purpose below.
    FlutterError.onError = (_) {};
    final logger = _Lines();
    logEveryError(logger);
    addTearDown(() {
      FlutterError.onError = testHandler;
      mtErrorSnackLog = null;
    });

    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        theme: mtTheme(MTVariant.superApp, Brightness.light),
        home: Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    showMTSnack(context, 'could not delete', type: MTSnackType.error);
    FlutterError.reportError(
      FlutterErrorDetails(exception: StateError('broken layout')),
    );
    await tester.pump();

    expect(logger.lines, contains('shown: could not delete'));
    expect(logger.lines.any((l) => l.contains('broken layout')), isTrue);
  });

  test('a file gone from the server is not called a wrong address', () {
    final l10n = lookupMTLocalizations(const Locale('en'));
    expect(
      errorText(l10n, const FileGoneException('HTTP 404 at /download')),
      l10n.errFileGone,
    );
    expect(errorText(l10n, const NoApiException()), l10n.errNoApi);
  });
}
