import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/update/update_section.dart';
import 'package:metube_super/features/update/update_state.dart';
import 'package:metube_super/features/update/whats_new_prompt.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'device_matrix.dart';

/// "What's new" once after an update: the decision is tested in mt_core,
/// and what is tested here belongs to the app: the notes are kept at the
/// check, the sheet speaks the reader's language, and it waits for the
/// screen to be free.
const _notes = '''
A feature release.

## Added

- **Read along while you listen.**
- **MeTube Lite: a family thing.**

## Which file

| | |
|---|---|
| **MeTube-Super-2.3.0.apk** | The server owner's build. |

---

**بالعربية:** إصدار ميزات.

- **اقرأ النص وأنت تستمع.**
- **Lite — شيء للعائلة.**
''';

void main() {
  late MemoryKeyValueStore store;

  setUp(() {
    store = MemoryKeyValueStore();
    PackageInfo.setMockInitialValues(
      appName: 'MeTube',
      packageName: 'com.yasir.test',
      version: '2.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  ProviderContainer container({String version = '2.3.0'}) {
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        installedVersionProvider.overrideWith((ref) async => (version, true)),
        updateCheckerProvider.overrideWithValue(
          UpdateChecker(
            assetMarker: 'super',
            fetch: (uri) async => uri.path.endsWith('/latest')
                ? json.encode({
                    'tag_name': 'v9.9.9',
                    'body': 'Newer notes',
                    'assets': [
                      {
                        'name': 'MeTube-Super-v9.9.9.apk',
                        'browser_download_url': 'https://example.invalid/a',
                      },
                    ],
                  })
                : throw Exception('offline'),
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  UpdatePrefs prefsOf(ProviderContainer c) => c.read(updatePrefsProvider);

  test('the update check keeps the notes for after the update', () async {
    final c = container();
    await c.read(updateControllerProvider.notifier).checkSilently();
    expect(await prefsOf(c).savedNotes(), ('9.9.9', 'Newer notes'));
  });

  group('the sheet after an update', () {
    WhatsNewOutcome? outcome;

    Widget host(ProviderContainer c, {Locale locale = const Locale('en')}) =>
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: mtTheme(MTVariant.superApp, Brightness.light),
            locale: locale,
            localizationsDelegates: MTLocalizations.localizationsDelegates,
            supportedLocales: MTLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () async =>
                      outcome = await maybeShowWhatsNew(context, ref),
                  child: const Text('launch'),
                ),
              ),
            ),
          ),
        );

    Future<void> launch(WidgetTester tester) async {
      outcome = null;
      await tester.tap(find.text('launch'));
      await tester.pumpAndSettle();
    }

    Future<ProviderContainer> updatedFrom221() async {
      final c = container();
      await prefsOf(c).setLastSeenVersion('2.2.1');
      await prefsOf(c).saveNotes('2.3.0', _notes);
      return c;
    }

    testWidgets('an English reader sees the English notes', (tester) async {
      await tester.pumpWidget(host(await updatedFrom221()));
      await launch(tester);
      expect(outcome, WhatsNewOutcome.shown);
      expect(find.text("What's new in 2.3.0"), findsOneWidget);
      expect(find.textContaining('Read along'), findsOneWidget);
      expect(find.textContaining('اقرأ النص'), findsNothing);
      expect(find.textContaining('.apk'), findsNothing);
      // An item written for the other app is not this reader's news.
      expect(find.textContaining('a family thing'), findsNothing);
    });

    testWidgets('an Arabic reader sees the Arabic summary', (tester) async {
      await tester.pumpWidget(
        host(await updatedFrom221(), locale: const Locale('ar')),
      );
      await launch(tester);
      expect(find.textContaining('اقرأ النص'), findsOneWidget);
      expect(find.textContaining('Read along'), findsNothing);
      expect(find.textContaining('شيء للعائلة'), findsNothing);
    });

    testWidgets('launch and resume asking at once show it once', (
      tester,
    ) async {
      final c = await updatedFrom221();
      final outcomes = <WhatsNewOutcome>[];
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: mtTheme(MTVariant.superApp, Brightness.light),
            localizationsDelegates: MTLocalizations.localizationsDelegates,
            supportedLocales: MTLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) => Scaffold(
                body: TextButton(
                  onPressed: () async => outcomes.addAll(
                    await Future.wait([
                      maybeShowWhatsNew(context, ref),
                      maybeShowWhatsNew(context, ref),
                    ]),
                  ),
                  child: const Text('both'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('both'));
      await tester.pumpAndSettle();
      expect(find.byType(MTWhatsNewSheet), findsOneWidget);
      expect(outcomes, contains(WhatsNewOutcome.shown));
    });

    testWidgets('it is shown once for a version', (tester) async {
      final c = await updatedFrom221();
      await tester.pumpWidget(host(c));
      await launch(tester);
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      await launch(tester);
      expect(outcome, WhatsNewOutcome.nothing);
      expect(find.text("What's new in 2.3.0"), findsNothing);
      expect(await prefsOf(c).lastSeenVersion(), '2.3.0');
    });

    testWidgets('it waits while something else is open, without spending '
        'its one showing', (tester) async {
      final c = await updatedFrom221();
      await tester.pumpWidget(host(c));
      MTRouteDepth.depth.value = 1;
      addTearDown(() => MTRouteDepth.depth.value = 0);
      await launch(tester);
      expect(outcome, WhatsNewOutcome.later);
      expect(await prefsOf(c).lastSeenVersion(), '2.2.1');

      MTRouteDepth.depth.value = 0;
      await launch(tester);
      expect(outcome, WhatsNewOutcome.shown);
    });

    testWidgets('settings opens it again after it was seen', (tester) async {
      final c = await updatedFrom221();
      await prefsOf(c).setLastSeenVersion('2.3.0');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            localizationsDelegates: MTLocalizations.localizationsDelegates,
            supportedLocales: MTLocalizations.supportedLocales,
            theme: mtTheme(MTVariant.superApp, Brightness.light),
            home: const Scaffold(
              body: SingleChildScrollView(child: UpdateSection()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text("What's new in this version"));
      await tester.pumpAndSettle();
      expect(find.text("What's new in 2.3.0"), findsOneWidget);
      expect(find.textContaining('Read along'), findsOneWidget);
    });

    testWidgets('offline with nothing saved, it points to the release page', (
      tester,
    ) async {
      final c = container();
      await prefsOf(c).setLastSeenVersion('2.2.1');
      await tester.pumpWidget(host(c));
      await launch(tester);
      final l10n = tester.element(find.byType(MTWhatsNewSheet)).mtl;
      expect(find.text(l10n.whatsNewUnavailable), findsOneWidget);
      expect(find.text(l10n.whatsNewReleasePage), findsOneWidget);
    });
  });

  testWidgets('**device matrix**: long notes keep the buttons in sight', (
    tester,
  ) async {
    final long = List.filled(
      30,
      '- **A change worth reading about.** With a line of detail.',
    ).join('\n');
    for (final notes in [long, '']) {
      await expectNoOverflow(
        tester,
        () => MaterialApp(
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          locale: const Locale('ar'),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          home: Scaffold(
            body: MTWhatsNewSheet(
              version: '2.3.0',
              notes: notes,
              onOpenPage: () {},
            ),
          ),
        ),
      );
    }
  });
}
