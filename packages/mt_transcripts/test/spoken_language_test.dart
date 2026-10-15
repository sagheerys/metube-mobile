import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:test/test.dart';

/// Owner's request 2026-10-15: subtitles in the language actually spoken,
/// beside the reader's own. The server only takes a language's name, so it
/// has to be read first, from the clip's own page.
void main() {
  // Shaped like a real watch page: a track's name holds arrays of its own.
  const page =
      'var x = {"captions":{"playerCaptionsTracklistRenderer":'
      '{"captionTracks":['
      '{"baseUrl":"https://x/a?b=[1]","name":{"runs":[{"text":"English"}]},'
      '"languageCode":"en","isTranslatable":true},'
      '{"baseUrl":"https://x/c","name":{"runs":[{"text":"Spanish (auto)"}]},'
      '"languageCode":"es","kind":"asr"}'
      '],"audioTracks":[]}}};';

  test('the speech-recognised track names the language spoken', () {
    expect(spokenLanguageIn(page), 'es');
  });

  test('a clip with no recognised speech, or no tracks, has none', () {
    expect(
      spokenLanguageIn('{"captionTracks":[{"languageCode":"en"}]}'),
      isNull,
    );
    expect(spokenLanguageIn('<html>no captions here</html>'), isNull);
  });

  test('a page that cannot be read is no language, not an error', () async {
    expect(
      await youtubeSpokenLanguage(
        'abc',
        get: (_) async => throw Exception('offline'),
      ),
      isNull,
    );
  });
}
