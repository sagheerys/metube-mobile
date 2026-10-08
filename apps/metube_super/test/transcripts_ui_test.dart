import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/library_models.dart';
import 'package:metube_super/features/library/library_providers.dart';
import 'package:metube_super/features/library/widgets/item_actions_sheet.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/transcripts/transcript_lines.dart';
import 'package:metube_super/features/transcripts/transcript_moment.dart';
import 'package:metube_super/features/transcripts/transcript_results.dart';
import 'package:metube_super/features/transcripts/transcript_sheet.dart';
import 'package:metube_super/features/transcripts/transcripts_section.dart';
import 'package:metube_super/features/transcripts/transcripts_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

import 'device_matrix.dart';

/// **The two screens of searching inside clips**: the settings section
/// that turns it on, and the moments listed under a library search.
void main() {
  const watch = 'https://www.youtube.com/watch?v=jNQXAC9IVRw';

  Transcript zoo() => Transcript(
    canonicalUrl: watch,
    language: 'en',
    source: 'captions',
    fetchedAt: DateTime.utc(2026, 9, 30),
    segments: const [
      TranscriptSegment(
        start: Duration(seconds: 7),
        end: Duration(seconds: 12),
        text: 'really really long trunks',
      ),
    ],
  );

  Future<ProviderContainer> container({
    bool enabled = false,
    int clips = 3,
    String query = '',
    bool clipInLibrary = true,
  }) async {
    final store = MemoryKeyValueStore();
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(const SuperSettings()),
        transcriptStatsProvider.overrideWith(
          (ref) async => (clips: clips, bytes: 48 * 1024),
        ),
        transcriptIndexProvider.overrideWith(
          (ref) async => TranscriptIndex()..add(zoo()),
        ),
        libraryItemsProvider.overrideWith(
          (ref) async => [
            if (clipInLibrary)
              const LibraryItem(
                canonicalUrl: watch,
                title: 'Me at the zoo',
                serverFilename: 'Me at the zoo.mp4',
                onServer: true,
              ),
          ],
        ),
      ],
    );
    addTearDown(c.dispose);
    if (enabled) await store.setBool(TranscriptsEnabled.prefsKey, true);
    if (query.isNotEmpty) c.read(libraryViewProvider.notifier).setQuery(query);
    return c;
  }

  Widget host(
    ProviderContainer c,
    Widget child, {
    Locale locale = const Locale('en'),
    Brightness brightness = Brightness.light,
  }) => UncontrolledProviderScope(
    container: c,
    child: MaterialApp(
      theme: mtTheme(MTVariant.superApp, brightness),
      locale: locale,
      localizationsDelegates: MTLocalizations.localizationsDelegates,
      supportedLocales: MTLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );

  Widget section() => ListView(
    padding: const EdgeInsets.all(MTSpace.pagePad),
    children: const [TranscriptsSection()],
  );

  Widget results() =>
      const CustomScrollView(slivers: [TranscriptResultsSliver()]);

  group('the settings section', () {
    testWidgets('off, it asks before turning on, and explains the cost', (
      tester,
    ) async {
      final c = await container();
      await tester.pumpWidget(host(c, section()));
      await tester.pumpAndSettle();
      expect(find.text('Export'), findsNothing);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.textContaining('up to 40 seconds'), findsOneWidget);

      await tester.tap(find.text('Turn on'));
      await tester.pumpAndSettle();
      expect(c.read(transcriptsEnabledProvider).valueOrNull, isTrue);
      expect(find.textContaining('3 clips'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);
    });

    testWidgets('cancelling the question leaves it off', (tester) async {
      final c = await container();
      await tester.pumpWidget(host(c, section()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(c.read(transcriptsEnabledProvider).valueOrNull, isFalse);
    });

    testWidgets('turning off keeps the transcripts unless told otherwise', (
      tester,
    ) async {
      final c = await container(enabled: true);
      await tester.pumpWidget(host(c, section()));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(find.text('Stop and keep'), findsOneWidget);
      expect(find.text('Stop and delete'), findsOneWidget);

      await tester.tap(find.text('Stop and keep'));
      await tester.pumpAndSettle();
      expect(c.read(transcriptsEnabledProvider).valueOrNull, isFalse);
    });

    testWidgets('an empty store offers import, not export or delete', (
      tester,
    ) async {
      final c = await container(enabled: true, clips: 0);
      await tester.pumpWidget(host(c, section()));
      await tester.pumpAndSettle();

      TextButton button(String label) => tester.widget<TextButton>(
        find.ancestor(of: find.text(label), matching: find.byType(TextButton)),
      );
      expect(button('Export').onPressed, isNull);
      expect(button('Delete all').onPressed, isNull);
      expect(button('Import').onPressed, isNotNull);
      expect(find.textContaining('No clips yet'), findsOneWidget);
    });

    testWidgets('help says what the switch cannot: YouTube, phone, backup', (
      tester,
    ) async {
      final c = await container();
      await tester.pumpWidget(host(c, section()));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.help_outline_rounded));
      await tester.pumpAndSettle();
      // Since 2.4.0 a server writing subtitle files covers every site; the
      // help says so, and which languages are read.
      expect(find.textContaining('Other sites are not covered'), findsNothing);
      expect(find.textContaining('other sites included'), findsOne);
      expect(find.textContaining("app's language and in English"), findsOne);
      expect(find.textContaining('does not include them'), findsOne);
      expect(find.textContaining('deletes nothing'), findsOne);
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets(
        'holds on every device and text scale (${locale.languageCode})',
        (tester) async {
          final c = await container(enabled: true);
          await expectNoOverflow(
            tester,
            () => host(c, section(), locale: locale),
          );
        },
      );
    }
  });

  group('the moments under a library search', () {
    testWidgets('a word said in a clip lists the clip and the second', (
      tester,
    ) async {
      final c = await container(enabled: true, query: 'long trunks');
      await tester.pumpWidget(host(c, results()));
      await tester.pumpAndSettle();

      expect(find.text('Said inside clips'), findsOneWidget);
      expect(find.text('Me at the zoo'), findsOneWidget);
      expect(find.text('really really long trunks'), findsOneWidget);
      expect(find.textContaining('0:07'), findsOneWidget);
    });

    testWidgets('case, spacing and punctuation in the query do not matter', (
      tester,
    ) async {
      final c = await container(enabled: true, query: 'LONG   TRUNKS!');
      await tester.pumpWidget(host(c, results()));
      await tester.pumpAndSettle();
      expect(find.text('Said inside clips'), findsOneWidget);
    });

    testWidgets('off, nothing is listed even when the words match', (
      tester,
    ) async {
      final c = await container(query: 'long trunks');
      await tester.pumpWidget(host(c, results()));
      await tester.pumpAndSettle();
      expect(find.text('Said inside clips'), findsNothing);
      expect(c.read(transcriptResultsProvider), isEmpty);
    });

    testWidgets('a clip no longer in the library is not listed', (
      tester,
    ) async {
      final c = await container(
        enabled: true,
        query: 'long trunks',
        clipInLibrary: false,
      );
      await tester.pumpWidget(host(c, results()));
      await tester.pumpAndSettle();
      expect(find.text('Said inside clips'), findsNothing);
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets(
        'holds on every device and text scale (${locale.languageCode})',
        (tester) async {
          final c = await container(enabled: true, query: 'trunks');
          await expectNoOverflow(
            tester,
            () => host(c, results(), locale: locale),
          );
        },
      );
    }
  });

  group('highlighting, context and the full transcript', () {
    Transcript talk(String language, List<String> lines) => Transcript(
      canonicalUrl: watch,
      language: language,
      source: 'captions',
      fetchedAt: DateTime.utc(2026, 9, 30),
      segments: [
        for (var i = 0; i < lines.length; i++)
          TranscriptSegment(
            start: Duration(seconds: i * 60),
            end: Duration(seconds: i * 60 + 5),
            text: lines[i],
          ),
      ],
    );

    Future<ProviderContainer> withTalk(
      List<Transcript> transcripts, {
      String query = 'trunks',
    }) async {
      final c = await container(enabled: true, query: query);
      c.read(transcriptIndexProvider.future).then((index) {
        for (final t in transcripts) {
          index.add(t);
        }
      });
      await c.read(transcriptIndexProvider.future);
      return c;
    }

    bool lit(InlineSpan span, Color background) {
      var found = false;
      span.visitChildren((child) {
        if (child is TextSpan && child.style?.backgroundColor == background) {
          found = true;
          return false;
        }
        return true;
      });
      return found;
    }

    testWidgets('the searched word is lit, and the next line gives context', (
      tester,
    ) async {
      final c = await withTalk([
        talk('en', ['long TRUNKS here', 'and that is cool']),
      ]);
      await tester.pumpWidget(host(c, results()));
      await tester.pumpAndSettle();

      final accentSoft = MTPalette.of(
        MTVariant.superApp,
        Brightness.light,
      ).accentSoft;
      expect(
        find.byWidgetPredicate((w) => w is RichText && lit(w.text, accentSoft)),
        findsWidgets,
      );
      expect(find.text('and that is cool'), findsOneWidget);
    });

    testWidgets('more places than shown are counted, and open the rest', (
      tester,
    ) async {
      final c = await withTalk([
        talk('en', [for (var i = 0; i < 5; i++) 'trunks number $i']),
      ]);
      await tester.pumpWidget(host(c, results()));
      await tester.pumpAndSettle();

      expect(find.text('Said 2 more times'), findsOneWidget);
      await tester.tap(find.text('Said 2 more times'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Full transcript'), findsOneWidget);
      expect(find.textContaining('5 matches'), findsOneWidget);
    });

    Widget sheet(ProviderContainer c, List<Transcript> transcripts) => host(
      c,
      TranscriptSheet(
        title: 'Me at the zoo',
        query: 'trunks',
        transcripts: transcripts,
        onMoment: (_) {},
      ),
    );

    testWidgets('the sheet opens on the language that holds the words', (
      tester,
    ) async {
      final c = await container(enabled: true);
      await tester.pumpWidget(
        sheet(c, [
          talk('ar', ['كلام']),
          talk('en', ['long trunks', 'more trunks']),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('English'), findsOneWidget);
      expect(find.textContaining('2 matches'), findsOneWidget);
      expect(find.textContaining('long trunks'), findsOneWidget);
    });

    testWidgets('a line of the sheet plays from its second', (tester) async {
      final c = await container(enabled: true);
      Duration? played;
      await tester.pumpWidget(
        host(
          c,
          TranscriptSheet(
            title: 'Me at the zoo',
            query: 'trunks',
            transcripts: [
              talk('en', ['intro', 'long trunks']),
            ],
            onMoment: (start) => played = start,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('intro'));
      expect(played, Duration.zero);
    });

    RichText richTextOf(WidgetTester tester, String plain) =>
        tester.widget<RichText>(
          find.byWidgetPredicate(
            (w) => w is RichText && w.text.toPlainText() == plain,
          ),
        );

    testWidgets('an English line under Arabic keeps its full stop at the end', (
      tester,
    ) async {
      final c = await withTalk([
        talk('en', ['long trunks here.', 'and that is cool.']),
      ]);
      await tester.pumpWidget(host(c, results(), locale: const Locale('ar')));
      await tester.pumpAndSettle();

      for (final line in ['long trunks here.', 'and that is cool.']) {
        final text = richTextOf(tester, line);
        expect(text.textDirection, TextDirection.ltr, reason: line);
        // Still against its time, on the interface's side.
        expect(text.textAlign, TextAlign.right, reason: line);
      }
      expect(
        richTextOf(tester, 'Me at the zoo').textDirection,
        TextDirection.ltr,
      );
    });

    testWidgets('an Arabic line under English reads right to left', (
      tester,
    ) async {
      final c = await withTalk([
        talk('ar', ['قال trunks هنا.']),
      ]);
      await tester.pumpWidget(host(c, results()));
      await tester.pumpAndSettle();

      final text = richTextOf(tester, 'قال trunks هنا.');
      expect(text.textDirection, TextDirection.rtl);
      expect(text.textAlign, TextAlign.left);
    });

    testWidgets('a phrase the captions split is lit on both lines', (
      tester,
    ) async {
      final c = await withTalk([
        talk('en', ['the long', 'trunks now']),
      ], query: 'long trunks');
      await tester.pumpWidget(host(c, results()));
      await tester.pumpAndSettle();

      final accentSoft = MTPalette.of(
        MTVariant.superApp,
        Brightness.light,
      ).accentSoft;
      expect(lit(richTextOf(tester, 'the long').text, accentSoft), isTrue);
      expect(lit(richTextOf(tester, 'trunks now').text, accentSoft), isTrue);
    });

    test('words found only inside clips still count as results', () async {
      final c = await container(enabled: true, query: 'long trunks');
      await c.read(transcriptsEnabledProvider.future);
      await c.read(transcriptIndexProvider.future);
      await c.read(libraryItemsProvider.future);
      // The title "Me at the zoo" does not match; what was said does.
      expect(c.read(visibleLibraryProvider).valueOrNull, isEmpty);
      expect(c.read(libraryResultCountProvider), 1);
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('the sheet holds on every device (${locale.languageCode})', (
        tester,
      ) async {
        final c = await container(enabled: true);
        final transcripts = [
          talk('ar', ['كلام طويل']),
          talk('en', [for (var i = 0; i < 12; i++) 'long trunks line $i']),
        ];
        await expectNoOverflow(
          tester,
          () => host(
            c,
            TranscriptSheet(
              title: 'A clip with a rather long title that wraps twice',
              query: 'trunks',
              transcripts: transcripts,
              onMoment: (_) {},
            ),
            locale: locale,
          ),
        );
      });
    }
  });

  group("a clip's menu", () {
    Widget menuHost(ProviderContainer c, LibraryItem item) => host(
      c,
      Consumer(
        builder: (context, ref, _) => TextButton(
          onPressed: () => showItemActionsSheet(context, ref, item),
          child: const Text('menu'),
        ),
      ),
    );

    testWidgets('offers the transcript of a clip that has one', (tester) async {
      final c = await container(enabled: true);
      await tester.pumpWidget(
        menuHost(
          c,
          const LibraryItem(
            canonicalUrl: watch,
            title: 'Me at the zoo',
            onServer: true,
          ),
        ),
      );
      await tester.tap(find.text('menu'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Transcript'));
      await tester.pumpAndSettle();

      expect(find.byType(TranscriptSheet), findsOneWidget);
      expect(find.text('really really long trunks'), findsOneWidget);
    });

    testWidgets('and not of one without', (tester) async {
      final c = await container(enabled: true);
      await tester.pumpWidget(
        menuHost(
          c,
          const LibraryItem(
            canonicalUrl: 'https://www.youtube.com/watch?v=aaaaaaaaaaa',
            title: 'Another clip',
            onServer: true,
          ),
        ),
      );
      await tester.tap(find.text('menu'));
      await tester.pumpAndSettle();
      expect(find.text('Details'), findsOneWidget);
      expect(find.text('Transcript'), findsNothing);
    });
  });

  group('following playback', () {
    Transcript lines(String language, List<String> texts) => Transcript(
      canonicalUrl: watch,
      language: language,
      source: 'captions',
      fetchedAt: DateTime.utc(2026, 9, 30),
      segments: [
        for (var i = 0; i < texts.length; i++)
          TranscriptSegment(
            start: Duration(seconds: i * 10),
            end: Duration(seconds: i * 10 + 9),
            text: texts[i],
          ),
      ],
    );

    TranscriptMomentRow row(WidgetTester tester, String text) =>
        tester.widget<TranscriptMomentRow>(
          find.byWidgetPredicate(
            (w) => w is TranscriptMomentRow && w.text == text,
          ),
        );

    test('the line being said is the last one begun', () {
      final segments = lines('en', ['a', 'b', 'c']).segments;
      expect(TranscriptLines.lineAt(segments, Duration.zero), 0);
      expect(TranscriptLines.lineAt(segments, const Duration(seconds: 15)), 1);
      expect(TranscriptLines.lineAt(segments, const Duration(minutes: 9)), 2);
      expect(
        TranscriptLines.lineAt(
          lines('en', ['late']).segments
              .map(
                (s) => TranscriptSegment(
                  start: const Duration(seconds: 5),
                  end: s.end,
                  text: s.text,
                ),
              )
              .toList(),
          Duration.zero,
        ),
        isNull,
      );
    });

    testWidgets('marks the line being said, and a tap jumps without closing', (
      tester,
    ) async {
      final c = await container(enabled: true);
      final ticks = StreamController<Duration>();
      addTearDown(ticks.close);
      final jumps = <Duration>[];
      await tester.pumpWidget(
        host(
          c,
          TranscriptSheet(
            title: 'Me at the zoo',
            query: '',
            transcripts: [
              lines('en', ['first', 'second', 'third']),
            ],
            position: ticks.stream,
            onMoment: jumps.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(row(tester, 'second').current, isFalse);

      ticks.add(const Duration(seconds: 12));
      await tester.pumpAndSettle();
      expect(row(tester, 'second').current, isTrue);
      expect(row(tester, 'first').current, isFalse);

      await tester.tap(find.text('third'));
      await tester.pumpAndSettle();
      expect(jumps, [const Duration(seconds: 20)]);
      expect(find.byType(TranscriptSheet), findsOneWidget);
    });

    testWidgets('closes once another item plays', (tester) async {
      final c = await container(enabled: true);
      final ticks = StreamController<Duration>.broadcast();
      addTearDown(ticks.close);
      var playing = true;
      await tester.pumpWidget(
        host(
          c,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => TranscriptSheet(
                  title: 'Me at the zoo',
                  query: '',
                  transcripts: [
                    lines('en', ['first']),
                  ],
                  position: ticks.stream,
                  stillPlaying: () => playing,
                  onMoment: (_) {},
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.byType(TranscriptSheet), findsOneWidget);

      playing = false;
      ticks.add(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(TranscriptSheet), findsNothing);
    });

    testWidgets('with nothing searched, opens on the interface language', (
      tester,
    ) async {
      final c = await container(enabled: true);
      await tester.pumpWidget(
        host(
          c,
          TranscriptSheet(
            title: 'Me at the zoo',
            query: '',
            transcripts: [
              lines('en', ['hello there']),
              lines('ar', ['مرحبا هناك']),
            ],
            onMoment: (_) {},
          ),
          locale: const Locale('ar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('مرحبا هناك'), findsOneWidget);
      expect(find.text('hello there'), findsNothing);
    });

    testWidgets('searching inside counts and lights the words', (tester) async {
      final c = await container(enabled: true);
      await tester.pumpWidget(
        host(
          c,
          TranscriptSheet(
            title: 'Me at the zoo',
            query: '',
            transcripts: [
              lines('en', ['long trunks', 'a zoo', 'more trunks']),
            ],
            onMoment: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('matches'), findsNothing);

      await tester.tap(find.byTooltip('Search the transcript'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'trunks');
      await tester.pumpAndSettle();
      expect(find.textContaining('2 matches'), findsOneWidget);
    });

    testWidgets('from a search: no second field, but arrows between matches', (
      tester,
    ) async {
      final c = await container(enabled: true);
      await tester.pumpWidget(
        host(
          c,
          TranscriptSheet(
            title: 'Me at the zoo',
            query: 'trunks',
            transcripts: [
              lines('en', [
                for (var i = 0; i < 60; i++)
                  i % 25 == 5 ? 'trunks at $i' : 'line $i',
              ]),
            ],
            onMoment: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.textContaining('3 matches'), findsOneWidget);
      expect(find.text('trunks at 5').hitTestable(), findsOneWidget);

      await tester.tap(find.byTooltip('Next match'));
      await tester.pumpAndSettle();
      expect(find.text('trunks at 30').hitTestable(), findsOneWidget);

      await tester.tap(find.byTooltip('Previous match'));
      await tester.pumpAndSettle();
      expect(find.text('trunks at 5').hitTestable(), findsOneWidget);
    });

    testWidgets('while playing, a search stays on its match', (tester) async {
      final c = await container(enabled: true);
      final ticks = StreamController<Duration>();
      addTearDown(ticks.close);
      await tester.pumpWidget(
        host(
          c,
          TranscriptSheet(
            title: 'Me at the zoo',
            query: 'trunks',
            transcripts: [
              lines('en', [
                for (var i = 0; i < 60; i++)
                  i % 25 == 5 ? 'trunks at $i' : 'line $i',
              ]),
            ],
            position: ticks.stream,
            onMoment: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Next match'));
      await tester.pumpAndSettle();
      expect(find.text('trunks at 30').hitTestable(), findsOneWidget);

      // Long after any hands-off pause, playback reaches a far line.
      await tester.pump(const Duration(seconds: 10));
      ticks.add(const Duration(seconds: 551));
      await tester.pumpAndSettle();
      expect(find.text('trunks at 30').hitTestable(), findsOneWidget);
    });

    testWidgets('beside a full-screen video it closes itself, not the page', (
      tester,
    ) async {
      final c = await container(enabled: true);
      final ticks = StreamController<Duration>.broadcast();
      addTearDown(ticks.close);
      var playing = true;
      var closed = 0;
      await tester.pumpWidget(
        host(
          c,
          TranscriptSheet(
            title: 'Me at the zoo',
            query: '',
            transcripts: [
              lines('en', ['first', 'second']),
            ],
            position: ticks.stream,
            stillPlaying: () => playing,
            onMoment: (_) {},
            onClose: () => closed++,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Dismiss'));
      expect(closed, 1);

      playing = false;
      ticks.add(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(closed, 2);
      expect(
        find.byType(TranscriptSheet),
        findsOneWidget,
        reason: 'not popped',
      );
    });

    for (final locale in const [Locale('en'), Locale('ar')]) {
      testWidgets('following holds on every device (${locale.languageCode})', (
        tester,
      ) async {
        final c = await container(enabled: true);
        await expectNoOverflow(
          tester,
          () => host(
            c,
            TranscriptSheet(
              title: 'A clip with a rather long title that wraps twice',
              query: '',
              transcripts: [
                lines('ar', ['كلام طويل']),
                lines('en', [for (var i = 0; i < 40; i++) 'line $i']),
              ],
              position: const Stream.empty(),
              onMoment: (_) {},
            ),
            locale: locale,
          ),
        );
      });
    }
  });
}
