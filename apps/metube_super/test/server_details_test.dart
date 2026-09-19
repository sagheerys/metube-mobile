import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/settings/widgets/server_status_card.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// **Asked 2026-09-19:** "the server's state, how many files are on it, and
/// whether a newer version of the server is out".
///
/// The endpoint that makes the last part possible is `GET /version`, read
/// from MeTube's source the same day and documented in `SERVER-API.md`
/// §2.6. The care in these tests is about **when to say nothing**: a server
/// that reports `dev`, one too old to answer at all, or a fork numbering
/// releases its own way must never be told it is out of date.
void main() {
  ProviderContainer containerWith({
    required ServerDetails? details,
    MTEndpointStatus status = MTEndpointStatus.ok,
  }) {
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(MemoryKeyValueStore()),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(
          const SuperSettings(activeUrl: 'https://mt.example.com'),
        ),
        serverStatusProvider.overrideWith((ref) async => status),
        serverDetailsProvider.overrideWith((ref) async => details),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Widget host(ProviderContainer c) => UncontrolledProviderScope(
    container: c,
    child: MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      theme: mtTheme(MTVariant.superApp, Brightness.light),
      home: const Scaffold(
        body: SingleChildScrollView(child: ServerStatusCard()),
      ),
    ),
  );

  group('what the card says about the server', () {
    testWidgets('the file count and the version', (tester) async {
      await tester.pumpWidget(
        host(
          containerWith(
            details: const ServerDetails(
              files: 128,
              queued: 0,
              version: ServerVersion(version: '2026.09.15'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('128'), findsOneWidget);
      expect(find.textContaining('2026.09.15'), findsOneWidget);
      // Nothing in the queue is not "0 in the queue": it is silence.
      expect(find.textContaining('الطابور'), findsNothing);
    });

    testWidgets('the queue is named only when something is in it', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          containerWith(
            details: const ServerDetails(
              files: 3,
              queued: 2,
              version: ServerVersion(version: '2026.09.15'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('الطابور'), findsOneWidget);
    });

    testWidgets('an older server is told, by its tag', (tester) async {
      await tester.pumpWidget(
        host(
          containerWith(
            details: const ServerDetails(
              files: 10,
              queued: 0,
              version: ServerVersion(version: '2026.08.28'),
              latestRelease: '2026.09.15',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The owner's own server on the day this was written.
      expect(find.textContaining('2026.09.15'), findsOneWidget);
    });

    testWidgets('a current server is told nothing', (tester) async {
      await tester.pumpWidget(
        host(
          containerWith(
            details: const ServerDetails(
              files: 10,
              queued: 0,
              version: ServerVersion(version: '2026.09.15'),
              latestRelease: '2026.09.15',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('يتوفر تحديث'), findsNothing);
    });

    testWidgets('`dev` is unknown, and is never called out of date', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          containerWith(
            details: const ServerDetails(
              files: 10,
              queued: 0,
              version: ServerVersion(version: 'dev'),
              latestRelease: '2026.09.15',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('غير معروفة'), findsOneWidget);
      expect(find.textContaining('يتوفر تحديث'), findsNothing);
    });

    testWidgets('a server too old to answer still shows its counts', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(containerWith(details: const ServerDetails(files: 7, queued: 0))),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('7'), findsOneWidget);
      expect(find.textContaining('غير معروفة'), findsOneWidget);
    });

    testWidgets('an unreachable server adds no second line', (tester) async {
      await tester.pumpWidget(
        host(
          containerWith(details: null, status: MTEndpointStatus.unreachable),
        ),
      );
      await tester.pumpAndSettle();

      // The state line above already says it; a placeholder underneath
      // would only repeat it.
      expect(find.textContaining('على الخادم'), findsNothing);
    });
  });

  testWidgets('**device matrix**: the added lines overflow nothing', (
    tester,
  ) async {
    await expectNoOverflow(
      tester,
      () => host(
        containerWith(
          details: const ServerDetails(
            files: 1284,
            queued: 12,
            version: ServerVersion(version: '2026.08.28'),
            latestRelease: '2026.09.15',
          ),
        ),
      ),
    );
  });
}
