import 'dart:io';

import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:test/test.dart';

void main() {
  test('the SRT a real MeTube server returned reads whole', () {
    // Fetched from a real server on 2026-09-29 (a subtitles-only job).
    final srt = File('test/fixtures/me_at_the_zoo.en.srt').readAsStringSync();
    final segments = SubtitleParser.parse(srt);

    expect(segments, hasLength(6));
    expect(segments.first.start, const Duration(seconds: 1, milliseconds: 200));
    expect(segments.first.end, const Duration(seconds: 3, milliseconds: 360));
    expect(
      segments.first.text,
      'All right, so here we are, in front of the elephants',
    );
    expect(segments[2].text, 'really really long trunks');
  });

  test('WebVTT: the header, notes and styling are dropped', () {
    const vtt =
        'WEBVTT\nKind: captions\nLanguage: en\n\n'
        'NOTE written by hand\n\n'
        '00:01.000 --> 00:02.500 align:start position:0%\n'
        '<c.colorE5E5E5>hello</c><00:00:01.500><c> there</c>\n\n'
        '1:00:00.000 --> 1:00:01.000\n'
        'an hour &amp; a second\n';
    final segments = SubtitleParser.parse(vtt);

    expect(segments.map((s) => s.text), ['hello there', 'an hour & a second']);
    expect(segments[0].start, const Duration(seconds: 1));
    expect(segments[1].start, const Duration(hours: 1));
  });

  test('rolling automatic captions keep each line once', () {
    // Each cue repeats the line before it, as YouTube's automatic
    // captions do. Without the fold every sentence is stored twice.
    const srt =
        '1\n00:00:00,000 --> 00:00:02,000\nfirst line\n\n'
        '2\n00:00:02,000 --> 00:00:04,000\nfirst line\nsecond line\n\n'
        '3\n00:00:04,000 --> 00:00:06,000\nsecond line\nthird line\n';
    final texts = SubtitleParser.parse(srt).map((s) => s.text);

    expect(texts, ['first line', 'second line', 'third line']);
  });

  test('a line after a pause keeps its own time, not the next line\'s', () {
    // As yt-dlp writes automatic captions: the first line after a pause
    // sits under an empty line, and each line is shown again for 10 ms
    // before the next. Cut at the empty line, "Okay" came out at 2.31 s
    // for 10 ms instead of at 0.88 s, and every line of a song was late.
    const srt =
        '1\n00:00:00,880 --> 00:00:02,310\n \nOkay, then my friends\n\n'
        '2\n00:00:02,310 --> 00:00:02,320\nOkay, then my friends\n \n\n'
        '3\n00:00:02,320 --> 00:00:03,950\nOkay, then my friends\n'
        "I'm going to show you\n\n"
        "4\n00:00:03,950 --> 00:00:03,960\nI'm going to show you\n \n\n"
        '5\n00:00:08,000 --> 00:00:09,500\n \nafter a pause\n\n'
        '6\n00:00:09,500 --> 00:00:09,510\nafter a pause\n \n';
    final segments = SubtitleParser.parse(srt);

    expect(segments.map((s) => (s.start.inMilliseconds, s.text)), [
      (880, 'Okay, then my friends'),
      (2320, "I'm going to show you"),
      (8000, 'after a pause'),
    ]);
    expect(
      segments.where((s) => s.end - s.start < const Duration(seconds: 1)),
      isEmpty,
      reason: 'no line lives only in a 10 ms echo',
    );
  });

  test('Windows line endings, a byte-order mark and Arabic text', () {
    final srt =
        '${String.fromCharCode(0xFEFF)}1\r\n'
        '00:00:01,000 --> 00:00:02,000\r\n'
        '<i>مرحبا</i>\r\n';
    final segments = SubtitleParser.parse(srt);

    expect(segments.single.text, 'مرحبا');
  });

  test('broken cues are skipped, never fatal', () {
    const srt =
        'garbage\n\n'
        '1\n00:00:xx,000 --> 00:00:02,000\nbad time\n\n'
        '2\n00:00:03,000 --> 00:00:04,000\n\n\n'
        '3\n00:00:05,000 --> 00:00:06,000\nkept\n';
    expect(SubtitleParser.parse(srt).map((s) => s.text), ['kept']);
  });

  group('when each word is said (2026-10-14)', () {
    // The shape of YouTube's automatic captions, as a server writes them
    // beside a clip: each cue repeats the line before it, and the new line
    // stamps the moment of every word after its first.
    const rolling =
        'WEBVTT\nKind: captions\nLanguage: en\n\n'
        '00:00:00.100 --> 00:00:01.300 align:start position:0%\n'
        ' \n'
        'Winter <00:00:00.500><c>is </c><00:00:00.900><c>coming</c>\n\n'
        '00:00:01.300 --> 00:00:01.330 align:start position:0%\n'
        'Winter is coming\n \n\n'
        '00:00:01.330 --> 00:00:02.400 align:start position:0%\n'
        'Winter is coming\n'
        'early, <00:00:01.700><c>so </c><00:00:02.050><c>pack</c>\n';

    test('every word keeps its moment, once', () {
      final segments = SubtitleParser.parse(rolling);
      expect(segments.map((s) => s.text), [
        'Winter is coming',
        'early, so pack',
      ]);
      final words = segments[1].words!;
      expect(words.map((w) => w.text), ['early,', 'so', 'pack']);
      expect(words.map((w) => w.start.inMilliseconds), [1330, 1700, 2050]);
      expect(segments[0].words!.first.start.inMilliseconds, 100);
    });

    test('stamped punctuation joins its word, and invisible spaces go', () {
      // Both measured on a server's files: a comma stamped on its own read
      // "happen , for", and two zero-width spaces after "AI" read as a word.
      final zwsp = String.fromCharCode(0x200B);
      final vtt =
          'WEBVTT\n\n'
          '00:00:01.000 --> 00:00:03.000\n'
          'what<00:00:01.400><c> would</c><00:00:01.800><c> happen</c>'
          '<00:00:02.000><c>,</c><00:00:02.100><c> for</c>\n\n'
          '00:00:03.000 --> 00:00:04.000\n'
          'the AI $zwsp$zwsp<00:00:03.500><c>form</c>\n';
      final segments = SubtitleParser.parse(vtt);
      expect(segments.map((s) => s.text), [
        'what would happen, for',
        'the AI form',
      ]);
      expect(segments[0].words!.map((w) => w.text), [
        'what',
        'would',
        'happen,',
        'for',
      ]);
      expect(segments[0].words![2].start.inMilliseconds, 1800);
      expect(segments[1].words!.map((w) => w.text), ['the', 'AI', 'form']);
    });

    test('subtitles with no stamps carry no words', () {
      const srt = '1\n00:00:01,000 --> 00:00:02,000\nhello there\n';
      expect(SubtitleParser.parse(srt).single.words, isNull);
    });

    test('words survive the file, and an older file reads as before', () {
      final read = Transcript(
        canonicalUrl: 'https://www.youtube.com/watch?v=jNQXAC9IVRw',
        language: 'en',
        source: 'captions',
        fetchedAt: DateTime.utc(2026, 10, 14),
        segments: SubtitleParser.parse(rolling),
        reader: SubtitleParser.version,
      );
      final back = Transcript.fromJson(read.toJson())!;
      expect(back.reader, SubtitleParser.version);
      expect(back.segments[1].words!.last.text, 'pack');
      expect(back.segments[1].words!.last.start.inMilliseconds, 2050);

      final old = read.toJson()
        ..remove('reader')
        ..['segments'] = [
          {'s': 0, 'e': 1000, 't': 'from before words'},
        ];
      final older = Transcript.fromJson(old)!;
      expect(older.reader, 1);
      expect(older.segments.single.words, isNull);
    });
  });
}
