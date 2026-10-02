import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:test/test.dart';

Transcript clip(String url, List<String> lines, {String language = 'en'}) =>
    Transcript(
      canonicalUrl: url,
      language: language,
      source: 'captions',
      fetchedAt: DateTime.utc(2026, 9, 30),
      segments: [
        for (var i = 0; i < lines.length; i++)
          TranscriptSegment(
            start: Duration(seconds: i * 10),
            end: Duration(seconds: i * 10 + 9),
            text: lines[i],
          ),
      ],
    );

void main() {
  late TranscriptIndex index;

  setUp(() => index = TranscriptIndex());

  test('finds the clip and the second it was said at', () {
    index
      ..add(clip('a', ['the weather', 'long trunks here']))
      ..add(clip('b', ['nothing relevant']));

    final results = index.search('TRUNKS');
    expect(results.single.canonicalUrl, 'a');
    expect(results.single.hits.single.start, const Duration(seconds: 10));
    expect(results.single.hits.single.text, 'long trunks here');
  });

  test('a phrase split across two captions is found, and counted once', () {
    index.add(clip('a', ['they have really', 'long trunks', 'the end']));

    final hits = index.search('really long').single.hits;
    expect(hits, hasLength(1));
    expect(hits.single.start, Duration.zero, reason: 'where the phrase starts');
  });

  test('a word inside one caption is not counted again at the line before', () {
    index.add(clip('a', ['elephants walk', 'trunks swing']));
    expect(index.search('trunks').single.hits, hasLength(1));
  });

  test('an Arabic query without hamza finds text written with one', () {
    // "ahlan" written with alef-hamza in the subtitles, typed bare.
    final written = String.fromCharCodes([0x0623, 0x0647, 0x0644, 0x0627]);
    final typed = String.fromCharCodes([0x0627, 0x0647, 0x0644, 0x0627]);
    index.add(clip('a', [written]));
    expect(index.search(typed), hasLength(1));
  });

  test('clips with more matches come first, each capped', () {
    index
      ..add(clip('once', ['cat']))
      ..add(clip('often', ['cat', 'cat', 'cat', 'cat']));

    final results = index.search('cat', perClip: 2);
    expect(results.map((r) => r.canonicalUrl), ['often', 'once']);
    expect(results.first.hits, hasLength(2));
  });

  test('a one-letter query finds nothing rather than everything', () {
    index.add(clip('a', ['a b c']));
    expect(index.search(' a '), isEmpty);
  });

  test('replacing and removing a clip', () {
    index
      ..add(clip('a', ['old words']))
      ..add(clip('a', ['new words']));
    expect(index.search('old'), isEmpty);
    expect(index.length, 1);

    index.remove('a');
    expect(index.search('new'), isEmpty);
    expect(index.contains('a'), isFalse);

    index.add(clip('b', const []));
    expect(
      index.contains('b'),
      isFalse,
      reason: 'an empty transcript adds nothing',
    );
  });

  group('words said apart', () {
    test('every word in one caption, in any order', () {
      index.add(clip('a', ['backup of the server files', 'other talk']));
      final hits = index.search('server backup').single.hits;
      expect(hits.single.kind, MatchKind.sameLine);
      expect(hits.single.start, Duration.zero);
    });

    test('every word within half a minute, across captions', () {
      // Lines ten seconds apart: the words sit two captions apart.
      index.add(
        clip('a', ['we keep a backup', 'every night', 'on the server']),
      );
      final hits = index.search('backup server').single.hits;
      expect(hits.single.kind, MatchKind.nearby);
      expect(hits.single.start, Duration.zero, reason: 'where it begins');
    });

    test('too far apart is two unrelated moments, not a match', () {
      index.add(
        clip('a', ['backup', 'a', 'b', 'c', 'd', 'server']), // 50 seconds
      );
      expect(index.search('backup server'), isEmpty);
    });

    test('a sentence found nearby is one moment, not one per caption', () {
      index.add(clip('a', ['backup here', 'backup again', 'the server']));
      expect(index.search('backup server').single.hits, hasLength(1));
    });

    test('the exact phrase outranks the same words said apart', () {
      index
        ..add(clip('apart', ['server first', 'then backup']))
        ..add(clip('exact', ['a server backup today']));
      final results = index.search('server backup');
      expect(results.map((r) => r.canonicalUrl), ['exact', 'apart']);
      expect(results.first.best, MatchKind.phrase);
    });
  });

  group('two languages', () {
    test('a clip lists its moments from both, once each', () {
      index
        ..add(clip('a', ['docker compose file'], language: 'en'))
        ..add(clip('a', ['ملف دوكر'], language: 'ar'));
      expect(index.length, 1, reason: 'one clip');
      expect(index.search('docker').single.hits.single.language, 'en');
      expect(index.transcriptsFor('a'), hasLength(2));
    });

    test('a word from each language never makes a match together', () {
      index
        ..add(clip('a', ['docker'], language: 'en'))
        ..add(clip('a', ['ملف'], language: 'ar'));
      expect(index.search('docker ملف'), isEmpty);
    });

    test('the same moment found in a translation too is listed once', () {
      index
        ..add(clip('a', ['backup server'], language: 'en'))
        ..add(clip('a', ['backup server'], language: 'ar'));
      final result = index.search('backup').single;
      expect(result.hits, hasLength(1));
      expect(result.total, 1);
    });
  });

  test('each moment carries the line after it, for context', () {
    index.add(clip('a', ['the cool thing', 'is the trunks']));
    final hit = index.search('cool').single.hits.single;
    expect(hit.next, 'is the trunks');
    expect(index.search('trunks').single.hits.single.next, isNull);
  });

  test('the closest matches are the ones kept when capped', () {
    index.add(clip('a', ['x one', 'x two', 'x three', 'backup server here']));
    final result = index.search('backup server', perClip: 1).single;
    expect(result.hits.single.text, 'backup server here');
  });
}
