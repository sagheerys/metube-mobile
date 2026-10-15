import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/features/shared/error_report.dart';
import 'package:metube_super/features/shared/error_text.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// Owner's request 2026-10-15: every error that shows, and every error
/// nobody caught, is in the diagnostic log.
void main() {
  testWidgets('error snack bars and framework errors reach the log', (
    tester,
  ) async {
    final file = File(
      '${Directory.systemTemp.path}/mtf_every_${DateTime.now().microsecondsSinceEpoch}.log',
    );
    addTearDown(() async {
      if (await file.exists()) await file.delete();
    });
    final present = FlutterError.onError;
    logEveryError(MTLogger(filePath: file.path));
    addTearDown(() {
      FlutterError.onError = present;
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
    // Stands in for an error while drawing; the test's own handler is
    // put back before it can fail the test.
    final reported = FlutterError.onError;
    FlutterError.onError = (details) => reported?.call(details);
    await tester.runAsync(() async {
      reported!(FlutterErrorDetails(exception: StateError('broken layout')));
      await Future<void>.delayed(const Duration(milliseconds: 200));
    });

    final log = await file.readAsString();
    expect(log, contains('shown: could not delete'));
    expect(log, contains('broken layout'));
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
