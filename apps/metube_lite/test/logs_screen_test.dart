import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/di.dart';
import 'package:metube_lite/features/settings/logs_screen.dart';
import 'package:metube_lite/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

/// The log in memory: a real file's reads run outside the test's clock.
class _MemoryLogger extends MTLogger {
  _MemoryLogger() : super(filePath: '');

  final List<String> lines = [];
  final StreamController<void> _written = StreamController<void>.broadcast();

  @override
  Stream<void> get changes => _written.stream;

  @override
  Future<void> log(
    String message, {
    LogLevel level = LogLevel.info,
    String? tag,
  }) async {
    lines.add('2026-10-23T10:00:00 INFO $message');
    _written.add(null);
  }

  @override
  Future<String> readAll() async => '${lines.join('\n')}\n';
}

void main() {
  late _MemoryLogger logger;

  setUp(() {
    logger = _MemoryLogger();
    for (var i = 0; i < 120; i++) {
      logger.lines.add('2026-10-23T09:00:00 INFO old line $i.');
    }
  });

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(411, 914);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
          secretStoreProvider.overrideWithValue(MemorySecretStore()),
          prefsMutexProvider.overrideWithValue(PrefsMutex()),
          initialSettingsProvider.overrideWithValue(const LiteSettings()),
          loggerProvider.overrideWithValue(logger),
        ],
        child: MaterialApp(
          theme: mtTheme(MTVariant.lite, Brightness.light),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          home: const LogsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> write(WidgetTester tester, String line) async {
    await logger.log(line);
    await tester.pump(MTMotion.medium);
    await tester.pumpAndSettle();
  }

  testWidgets('a new line shows up without a refresh, and a reader at the '
      'bottom is carried down to it', (tester) async {
    await open(tester);
    await tester.fling(find.byType(ListView), const Offset(0, -20000), 5000);
    await tester.pumpAndSettle();

    await write(tester, 'the newest line');
    expect(find.textContaining('the newest line'), findsOneWidget);
  });

  testWidgets('a reader higher up is not moved, and the arrow takes them '
      'down', (tester) async {
    await open(tester);
    final first = find.textContaining('old line 0.');
    final before = tester.getTopLeft(first).dy;

    await write(tester, 'the newest line');
    expect(tester.getTopLeft(first).dy, before);
    expect(find.textContaining('the newest line'), findsNothing);

    await tester.tap(find.byTooltip('Go to the newest'));
    await tester.pumpAndSettle();
    expect(find.textContaining('the newest line'), findsOneWidget);
  });
}
