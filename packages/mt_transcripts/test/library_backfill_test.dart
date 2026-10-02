import 'dart:io';

import 'package:mt_core/mt_core.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:mt_transcripts/src/library_backfill.dart';
import 'package:mt_transcripts/src/subtitle_source.dart';
import 'package:mt_transcripts/src/yt_dlp_source.dart';
import 'package:test/test.dart';

String watch(String id) => 'https://www.youtube.com/watch?v=$id';

String srt(String line) => '1\n00:00:01,000 --> 00:00:03,000\n$line\n';

class Video {
  const Video({
    this.written = const {},
    this.automatic = const {},
    this.texts = const {},
    this.error,
    this.refuseTranslations = false,
  });

  final Set<String> written;
  final Set<String> automatic;
  final Map<String, String> texts;
  final Exception? error;
  final bool refuseTranslations;
}

/// Answers like yt-dlp would, and records what was asked.
class FakeSource implements SubtitleSource {
  FakeSource(this.videos);

  final Map<String, Video> videos;
  final asked = <String>[];
  final chosen = <String, List<TrackChoice>>{};

  @override
  Future<FetchedTracks> fetch(
    String url,
    List<TrackChoice> Function(OfferedTracks offered) choose,
  ) async {
    asked.add(url);
    final video = videos[url]!;
    if (video.error case final error?) throw error;
    final choices = choose(
      OfferedTracks(written: video.written, automatic: video.automatic),
    );
    chosen[url] = choices;
    bool refused(TrackChoice c) =>
        video.refuseTranslations && c.kind == TrackKind.translated;
    return FetchedTracks({
      for (final c in choices)
        if (!refused(c)) c.track: ?video.texts[c.track],
    }, translationsRefused: choices.any(refused));
  }
}

void main() {
  late Directory work;
  final waits = <Duration>[];

  setUp(() {
    work = Directory.systemTemp.createTempSync('backfill-test-');
    waits.clear();
  });
  tearDown(() => work.deleteSync(recursive: true));

  HistoryItem clip(String id, {String? type}) => HistoryItem.fromJson({
    'id': id,
    'url': watch(id),
    'title': 'clip $id',
    'status': 'finished',
    'download_type': ?type,
  });

  LibraryBackfill backfill(
    FakeSource source, {
    List<String> languages = const ['ar', 'en'],
    bool translations = false,
  }) => LibraryBackfill(
    source: source,
    work: work,
    languages: languages,
    translations: translations,
    wait: (d) async => waits.add(d),
    clock: () => DateTime.utc(2026, 9, 30),
  );

  group('which clips', () {
    test('finished YouTube videos only, once each', () {
      final history = HistoryResponse(
        queue: [clip('queuedVideo')],
        done: [
          clip('aaaaaaaaaaa'),
          clip('aaaaaaaaaaa'),
          clip('ccccccccccc', type: 'captions'),
          HistoryItem.fromJson({
            'id': 'x',
            'url': 'https://www.instagram.com/reel/abc/',
            'status': 'finished',
          }),
        ],
      );
      expect(LibraryBackfill.candidates(history).map((c) => c.canonicalUrl), [
        watch('aaaaaaaaaaa'),
      ]);
    });
  });

  group('which track', () {
    List<String> pick(
      OfferedTracks offered, {
      bool translations = false,
      List<String> languages = const ['en'],
    }) => [
      for (final c in LibraryBackfill.pickTracks(
        offered,
        languages,
        translations: translations,
      ))
        '${c.language}=${c.track}/${c.kind.name}',
    ];

    test('written subtitles beat the spoken words', () {
      expect(
        pick(const OfferedTracks(written: {'en'}, automatic: {'en-orig'})),
        ['en=en/written'],
      );
      expect(pick(const OfferedTracks(written: {'en-GB', 'en-US'})), [
        'en=en-GB/written',
      ]);
    });

    test('the spoken words, even under a regional name', () {
      expect(pick(const OfferedTracks(automatic: {'en', 'ar', 'en-US-orig'})), [
        'en=en-US-orig/spoken',
      ]);
      expect(
        pick(const OfferedTracks(automatic: {'english-orig', 'e-orig'})),
        isEmpty,
      );
    });

    test('a translation only when asked for', () {
      const offered = OfferedTracks(automatic: {'en', 'ar', 'es-orig'});
      expect(pick(offered, languages: ['ar', 'en']), isEmpty);
      expect(pick(offered, languages: ['ar', 'en'], translations: true), [
        'ar=ar/translated',
        'en=en/translated',
      ]);
    });
  });

  group('a run', () {
    test('keeps each language found, and marks the rest', () async {
      final source = FakeSource({
        watch('aaaaaaaaaaa'): Video(
          automatic: const {'en-orig', 'ar'},
          texts: {'en-orig': srt('hello world')},
        ),
      });
      final report = await backfill(source).run([clip('aaaaaaaaaaa')]);

      expect(report.saved, 1);
      expect(report.nothingOffered, 1);
      final saved = TranscriptBundle.decode(await backfill(source).bundle())!;
      expect(saved.single.canonicalUrl, watch('aaaaaaaaaaa'));
      expect(saved.single.language, 'en');
      expect(saved.single.segments.single.text, 'hello world');
    });

    test('a second run asks nothing already answered', () async {
      final source = FakeSource({
        watch('aaaaaaaaaaa'): Video(
          automatic: const {'en-orig'},
          texts: {'en-orig': srt('hello')},
        ),
        watch('bbbbbbbbbbb'): const Video(),
      });
      final clips = [clip('aaaaaaaaaaa'), clip('bbbbbbbbbbb')];
      await backfill(source).run(clips);
      expect(source.asked, hasLength(2));

      final again = await backfill(source).run(clips);
      expect(source.asked, hasLength(2));
      expect(again.alreadyDone, 2);
    });

    test('pauses between videos, not before the first', () async {
      final source = FakeSource({
        for (final id in ['aaaaaaaaaaa', 'bbbbbbbbbbb', 'ccccccccccc'])
          watch(id): const Video(),
      });
      await backfill(source)
          .run([clip('aaaaaaaaaaa'), clip('bbbbbbbbbbb'), clip('ccccccccccc')]);
      expect(waits, hasLength(2));
    });

    test('a limit counts videos asked, not videos skipped', () async {
      final source = FakeSource({
        for (final id in ['aaaaaaaaaaa', 'bbbbbbbbbbb', 'ccccccccccc'])
          watch(id): const Video(),
      });
      final clips = [
        clip('aaaaaaaaaaa'),
        clip('bbbbbbbbbbb'),
        clip('ccccccccccc'),
      ];
      await backfill(source).run(clips, limit: 1);
      await backfill(source).run(clips, limit: 1);
      expect(source.asked, [watch('aaaaaaaaaaa'), watch('bbbbbbbbbbb')]);
    });

    test('too many requests stops the run there, and it resumes', () async {
      final source = FakeSource({
        watch('aaaaaaaaaaa'): const Video(
          error: BackfillRateLimited('HTTP Error 429'),
        ),
        watch('bbbbbbbbbbb'): const Video(),
      });
      final clips = [clip('aaaaaaaaaaa'), clip('bbbbbbbbbbb')];
      final report = await backfill(source).run(clips);
      expect(report.stoppedByRateLimit, isTrue);
      expect(source.asked, [watch('aaaaaaaaaaa')]);

      source.videos[watch('aaaaaaaaaaa')] = const Video();
      await backfill(source).run(clips);
      expect(source.asked, hasLength(3));
    });

    test('a video gone is never asked again; a failure is', () async {
      final source = FakeSource({
        watch('aaaaaaaaaaa'): const Video(error: VideoGone('Private video')),
        watch('bbbbbbbbbbb'): const Video(error: FetchFailed('network')),
      });
      final clips = [clip('aaaaaaaaaaa'), clip('bbbbbbbbbbb')];
      final first = await backfill(source).run(clips);
      expect((first.gone, first.failed), (1, 1));

      await backfill(source).run(clips);
      expect(source.asked, [
        watch('aaaaaaaaaaa'),
        watch('bbbbbbbbbbb'),
        watch('bbbbbbbbbbb'),
      ]);
    });

    test('with translations, what was missing before is asked again', () async {
      final source = FakeSource({
        watch('aaaaaaaaaaa'): Video(
          automatic: const {'en-orig', 'ar'},
          texts: {'en-orig': srt('hello'), 'ar': srt('مرحبا')},
        ),
      });
      final clips = [clip('aaaaaaaaaaa')];
      await backfill(source).run(clips);
      await backfill(source, translations: true).run(clips);

      expect(source.asked, hasLength(2));
      expect(source.chosen[watch('aaaaaaaaaaa')]!.single.language, 'ar');
      final saved = TranscriptBundle.decode(await backfill(source).bundle())!;
      expect(saved.map((t) => t.language).toSet(), {'ar', 'en'});
    });

    test(
      'translations refused: none are asked for the rest of the run',
      () async {
        final source = FakeSource({
          watch('aaaaaaaaaaa'): Video(
            automatic: const {'en-orig', 'ar'},
            texts: {'en-orig': srt('hello'), 'ar': srt('مرحبا')},
            refuseTranslations: true,
          ),
          watch('bbbbbbbbbbb'): const Video(automatic: {'en-orig', 'ar'}),
        });
        final report = await backfill(
          source,
          translations: true,
        ).run([clip('aaaaaaaaaaa'), clip('bbbbbbbbbbb')]);

        expect(report.translationsRefused, isTrue);
        expect(source.chosen[watch('bbbbbbbbbbb')]!.map((c) => c.kind), [
          TrackKind.spoken,
        ]);
        // The refused translation stays unanswered, so a later run asks it.
        expect(File('${work.path}/aaaaaaaaaaa.ar.none').existsSync(), isFalse);
      },
    );

    test('empty subtitles count as none', () async {
      final source = FakeSource({
        watch('aaaaaaaaaaa'): const Video(
          automatic: {'en-orig'},
          texts: {'en-orig': ''},
        ),
      });
      final report = await backfill(
        source,
        languages: ['en'],
      ).run([clip('aaaaaaaaaaa')]);
      expect((report.saved, report.nothingOffered), (0, 1));
    });
  });

  group('reading yt-dlp', () {
    test('its errors: blocked, gone, or worth another try', () {
      expect(
        YtDlpSource.classify(
          "ERROR: Unable to download video subtitles for 'ar': "
          'HTTP Error 429: Too Many Requests',
        ),
        isA<BackfillRateLimited>(),
      );
      expect(
        YtDlpSource.classify('ERROR: [youtube] x: Video unavailable'),
        isA<VideoGone>(),
      );
      expect(
        YtDlpSource.classify(
          'WARNING: earlier HTTP Error 429 retried\nERROR: timed out',
        ),
        isA<FetchFailed>(),
      );
    });

    test('its tracks, without the live chat', () {
      final offered = YtDlpSource.offeredIn({
        'subtitles': {'en': [], 'live_chat': []},
        'automatic_captions': {'en-orig': [], 'ar': []},
      });
      expect(offered.written, {'en'});
      expect(offered.automatic, {'en-orig', 'ar'});
      expect(YtDlpSource.offeredIn('nonsense').written, isEmpty);
    });
  });
}
