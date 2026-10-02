import 'dart:convert';

import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:test/test.dart';

void main() {
  Transcript clip(String id) => Transcript(
    canonicalUrl: 'https://www.youtube.com/watch?v=$id',
    language: 'ar',
    source: 'captions',
    fetchedAt: DateTime.utc(2026, 9, 30),
    segments: const [
      TranscriptSegment(
        start: Duration.zero,
        end: Duration(seconds: 2),
        text: 'x',
      ),
    ],
  );

  test('an export restores every transcript whole', () {
    final back = TranscriptBundle.decode(
      TranscriptBundle.encode([clip('a'), clip('b')]),
    );
    expect(back!.map((t) => t.toJson()), [
      clip('a').toJson(),
      clip('b').toJson(),
    ]);
  });

  test('a settings backup picked by mistake is refused, not half-read', () {
    expect(
      TranscriptBundle.decode(jsonEncode({'app': 'MTF', 'prefs': {}})),
      isNull,
    );
    expect(TranscriptBundle.decode('not json'), isNull);
    expect(
      TranscriptBundle.decode(jsonEncode({'kind': TranscriptBundle.kind})),
      isNull,
    );
  });

  test('an unreadable entry is skipped, the rest imported', () {
    final raw = jsonEncode({
      'kind': TranscriptBundle.kind,
      'version': 1,
      'transcripts': [
        clip('a').toJson(),
        {'broken': true},
      ],
    });
    expect(TranscriptBundle.decode(raw), hasLength(1));
  });
}
