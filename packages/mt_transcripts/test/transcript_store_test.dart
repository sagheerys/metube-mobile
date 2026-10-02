import 'dart:convert';
import 'dart:io';

import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late TranscriptStore store;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('mtf_transcripts');
    store = TranscriptStore(Directory('${temp.path}/transcripts'));
  });
  tearDown(() => temp.deleteSync(recursive: true));

  final sample = Transcript(
    canonicalUrl: 'https://www.youtube.com/watch?v=jNQXAC9IVRw',
    language: 'en',
    source: 'captions',
    fetchedAt: DateTime.utc(2026, 9, 30, 12),
    segments: const [
      TranscriptSegment(
        start: Duration(milliseconds: 1200),
        end: Duration(milliseconds: 3360),
        text: 'All right, so here we are',
      ),
    ],
  );

  test(
    'nothing exists on disk until the first transcript is written',
    () async {
      // Privacy: a phone that never turns the feature on never
      // gets the folder.
      expect(await store.read(sample.canonicalUrl, 'en'), isNull);
      expect(await store.sizeBytes(), 0);
      expect(await store.readAll().toList(), isEmpty);
      expect(store.root.existsSync(), isFalse);

      await store.write(sample);
      expect(store.root.existsSync(), isTrue);
    },
  );

  test('a transcript survives the round trip whole', () async {
    await store.write(sample);
    final back = await store.read(sample.canonicalUrl, 'en');

    expect(back!.toJson(), sample.toJson());
    expect(await store.has(sample.canonicalUrl), isTrue);
    expect(
      store.root.listSync().map((e) => e.path).where((p) => p.endsWith('.tmp')),
      isEmpty,
      reason: 'the temporary file is renamed, not left behind',
    );
  });

  test('a file holding another clip reads as no transcript', () async {
    await store.write(sample);
    final file = store.root.listSync().single as File;
    final other = sample.toJson()..['url'] = 'https://example.com/other';
    file.writeAsStringSync(jsonEncode(other));

    expect(await store.read(sample.canonicalUrl, 'en'), isNull);
  });

  test(
    'broken files and newer formats are skipped, the rest still read',
    () async {
      await store.write(sample);
      File('${store.root.path}/broken.json').writeAsStringSync('{not json');
      File('${store.root.path}/future.json').writeAsStringSync(
        jsonEncode(sample.toJson()..['schema'] = Transcript.schema + 1),
      );

      final all = await store.readAll().toList();
      expect(all.map((t) => t.canonicalUrl), [sample.canonicalUrl]);
    },
  );

  test('size, remove and clear', () async {
    await store.write(sample);
    expect(await store.sizeBytes(), greaterThan(0));

    await store.remove(sample.canonicalUrl);
    expect(await store.read(sample.canonicalUrl, 'en'), isNull);
    await store.remove(sample.canonicalUrl); // a second remove is harmless

    await store.write(sample);
    await store.clear();
    expect(store.root.existsSync(), isFalse);
  });

  test('distinct URLs get distinct files', () async {
    for (var i = 0; i < 50; i++) {
      await store.write(
        Transcript(
          canonicalUrl: 'https://www.youtube.com/watch?v=clip$i',
          language: 'en',
          source: 'captions',
          fetchedAt: DateTime.utc(2026),
          segments: sample.segments,
        ),
      );
    }
    expect(store.root.listSync(), hasLength(50));
  });

  test('a clip keeps one transcript per language, side by side', () async {
    final arabic = Transcript(
      canonicalUrl: sample.canonicalUrl,
      language: 'ar',
      source: 'captions',
      fetchedAt: sample.fetchedAt,
      segments: sample.segments,
    );
    await store.write(sample);
    await store.write(arabic);

    expect((await store.read(sample.canonicalUrl, 'ar'))!.language, 'ar');
    expect((await store.read(sample.canonicalUrl, 'en'))!.language, 'en');
    expect(await store.readFor(sample.canonicalUrl), hasLength(2));

    await store.remove(sample.canonicalUrl);
    expect(await store.readFor(sample.canonicalUrl), isEmpty);
  });

  test('a transcript kept before languages existed is still read, and '
      'replaced rather than doubled when fetched again', () async {
    // The one-file-per-clip name the store used first. Installs from the
    // first release still have transcripts saved under it.
    String legacyName(String key) {
      var hash = 0xcbf29ce484222325;
      for (final byte in utf8.encode(key)) {
        hash ^= byte;
        hash *= 0x100000001b3;
      }
      String half(int v) => v.toRadixString(16).padLeft(8, '0');
      return '${half(hash >>> 32)}${half(hash & 0xFFFFFFFF)}.json';
    }

    store.root.createSync(recursive: true);
    File('${store.root.path}/${legacyName(sample.canonicalUrl)}')
        .writeAsStringSync(jsonEncode(sample.toJson()));

    expect((await store.read(sample.canonicalUrl, 'en'))!.language, 'en');
    expect(await store.readAll().toList(), hasLength(1));

    await store.write(sample);
    expect(store.root.listSync(), hasLength(1), reason: 'no duplicate left');
    expect(await store.readAll().toList(), hasLength(1));
  });

  test('an old file labelled after its subtitle file (ar-orig) is one '
      'language with ar, and goes once ar exists', () async {
    // Field report: a third tab named "ar-orig" beside
    // Arabic and English, for the one clip fetched by the first version.
    String legacyName(String key) {
      var hash = 0xcbf29ce484222325;
      for (final byte in utf8.encode(key)) {
        hash ^= byte;
        hash *= 0x100000001b3;
      }
      String half(int v) => v.toRadixString(16).padLeft(8, '0');
      return '${half(hash >>> 32)}${half(hash & 0xFFFFFFFF)}.json';
    }

    final arabic = Transcript(
      canonicalUrl: sample.canonicalUrl,
      language: 'ar',
      source: 'captions',
      fetchedAt: DateTime.utc(2026, 9, 30),
      segments: sample.segments,
    );
    await store.write(arabic);
    await store.write(sample);
    final legacy = File(
      '${store.root.path}/${legacyName(sample.canonicalUrl)}',
    );
    legacy.writeAsStringSync(
      jsonEncode({...arabic.toJson(), 'lang': 'ar-orig'}),
    );

    final kept = await store.readFor(sample.canonicalUrl);
    expect(kept.map((t) => t.language).toList()..sort(), ['ar', 'en']);
    expect(legacy.existsSync(), isFalse);
  });

  test('a language is its first part, in lower case', () {
    expect(Transcript.baseLanguage('ar-orig'), 'ar');
    expect(Transcript.baseLanguage('en-US'), 'en');
    expect(Transcript.baseLanguage('AR'), 'ar');
    expect(Transcript.baseLanguage('und'), 'und');
  });
}
