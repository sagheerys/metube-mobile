import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:metube_super/features/transcripts/subtitles.dart';
import 'package:metube_super/features/transcripts/transcripts_state.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_ui/mt_ui.dart';

/// **Subtitles from the transcripts (owner's request 2026-10-14)**: off
/// until asked for, every choice kept, and in the app's language first.
void main() {
  const url = 'https://www.youtube.com/watch?v=jNQXAC9IVRw';

  Transcript talk(String language, String text, {bool timed = false}) =>
      Transcript(
        canonicalUrl: url,
        language: language,
        source: 'captions',
        fetchedAt: DateTime.utc(2026, 10, 14),
        segments: [
          TranscriptSegment(
            start: const Duration(seconds: 1),
            end: const Duration(seconds: 2),
            text: text,
            words: timed
                ? const [
                    TranscriptWord(Duration(seconds: 1), 'hello'),
                    TranscriptWord(Duration(milliseconds: 1500), 'there'),
                  ]
                : null,
          ),
        ],
      );

  Future<(ProviderContainer, MemoryKeyValueStore)> container({
    bool enabled = true,
    String locale = 'ar',
  }) async {
    final store = MemoryKeyValueStore();
    final c = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(
          SuperSettings(localeCode: locale),
        ),
        transcriptIndexProvider.overrideWith(
          (ref) async => TranscriptIndex()
            ..add(talk('en', 'hello there', timed: true))
            ..add(talk('ar', 'مرحبا هناك')),
        ),
      ],
    );
    addTearDown(c.dispose);
    if (enabled) await store.setBool(TranscriptsEnabled.prefsKey, true);
    await c.read(transcriptsEnabledProvider.future);
    await c.read(transcriptIndexProvider.future);
    return (c, store);
  }

  test('the app\'s language first, with each word\'s moment', () async {
    final (ar, _) = await container();
    expect(ar.read(subtitleLinesProvider(url))!.single.text, 'مرحبا هناك');

    final (en, _) = await container(locale: 'en');
    final line = en.read(subtitleLinesProvider(url))!.single;
    expect(line.text, 'hello there');
    expect(line.words!.last.start, const Duration(milliseconds: 1500));
  });

  test('every language the clip has, the app\'s own first', () async {
    final (ar, _) = await container();
    expect(ar.read(subtitleTracksProvider(url))!.keys, ['ar', 'en']);
    final (en, _) = await container(locale: 'en');
    expect(en.read(subtitleTracksProvider(url))!.keys, ['en', 'ar']);
  });

  test('the language picked with the switch is kept', () async {
    final (c, store) = await container();
    final prefs = c.read(subtitlePrefsProvider);
    await pumpEventQueue();
    prefs.language.value = 'en';
    await pumpEventQueue();
    expect(await store.getString('subtitles_language'), 'en');
    prefs.language.value = null;
    await pumpEventQueue();
    expect(await store.getString('subtitles_language'), isNull);
  });

  test('no subtitles while transcripts are off', () async {
    final (c, _) = await container(enabled: false);
    expect(c.read(subtitleLinesProvider(url)), isNull);
  });

  testWidgets('off and medium until chosen, and every choice is kept', (
    tester,
  ) async {
    final (c, store) = (await tester.runAsync(container))!;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: mtTheme(MTVariant.superApp, Brightness.light),
          localizationsDelegates: MTLocalizations.localizationsDelegates,
          supportedLocales: MTLocalizations.supportedLocales,
          home: const Scaffold(
            body: SingleChildScrollView(child: SubtitleSettings()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final prefs = c.read(subtitlePrefsProvider);
    expect(prefs.shown.value, isFalse);
    expect(prefs.inShorts.value, isFalse);
    expect(prefs.size.value, 1);
    expect(prefs.backdrop, MTCaptionBackground.solid);

    await tester.tap(find.text('Show subtitles'));
    await tester.tap(find.text('Large'));
    await tester.tap(find.text('None'));
    await tester.tap(find.text('Subtitles in shorts'));
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      expect(await store.getBool('subtitles_shown'), isTrue);
      expect(await store.getInt('subtitles_size'), 2);
      expect(await store.getBool('subtitles_in_shorts'), isTrue);
      expect(await store.getInt('subtitles_background'), 2);
    });
    expect(prefs.scale, greaterThan(1));
  });
}
