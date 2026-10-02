import 'package:mt_core/mt_core.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:test/test.dart';

/// **The subtitle file a server writes beside a clip is found by name**,
/// never by listing a folder: yt-dlp names it after the media file with the
/// extension swapped (measured 2026-10-02 on a real server, for a video and
/// an audio download alike).
void main() {
  const watch = 'https://www.youtube.com/watch?v=jNQXAC9IVRw';
  const media = 'Me at the zoo [jNQXAC9IVRw].webm';
  const vtt =
      'WEBVTT\nKind: captions\nLanguage: en\n\n'
      '00:00:01.200 --> 00:00:03.360\nhere we are\n';
  const srt = '1\n00:00:01,200 --> 00:00:03,360\nthe elephants\n';

  late _FakeServer server;
  setUp(() => server = _FakeServer());

  Future<SidecarResult> read({String language = 'en'}) =>
      SidecarReader(server)
          .read(canonicalUrl: watch, filename: media, language: language);

  group('the names', () {
    test('swap the media extension, dots in the title kept', () {
      expect(SidecarReader.namesFor('a.b.c [id].mp4', 'ar'), [
        'a.b.c [id].ar.vtt',
        'a.b.c [id].ar.srt',
      ]);
      // The colon yt-dlp writes as its full-width twin stays as it is.
      expect(
        SidecarReader.namesFor('Spider-Man： Into [x].m4a', 'en').first,
        'Spider-Man： Into [x].en.vtt',
      );
    });

    test('a name without an extension is used whole', () {
      expect(SidecarReader.namesFor('clip', 'en').first, 'clip.en.vtt');
    });
  });

  test('found as vtt, the language asked for is the one stored', () async {
    server.texts['Me at the zoo [jNQXAC9IVRw].en.vtt'] = vtt;
    final result = await read();
    expect(result.outcome, SidecarOutcome.found);
    expect(result.transcript!.canonicalUrl, watch);
    expect(result.transcript!.language, 'en');
    expect(result.transcript!.segments.single.text, 'here we are');
    expect(server.asked, ['Me at the zoo [jNQXAC9IVRw].en.vtt']);
  });

  test('srt is tried after vtt', () async {
    server.texts['Me at the zoo [jNQXAC9IVRw].en.srt'] = srt;
    final result = await read();
    expect(result.outcome, SidecarOutcome.found);
    expect(result.transcript!.segments.single.text, 'the elephants');
    expect(server.asked, hasLength(2));
  });

  test('neither name on the server is a miss, not a failure', () async {
    final result = await read();
    expect(result.outcome, SidecarOutcome.none);
    expect(result.transcript, isNull);
  });

  test('a file with no cues is a miss too', () async {
    server.texts['Me at the zoo [jNQXAC9IVRw].ar.vtt'] = 'WEBVTT\n';
    expect((await read(language: 'ar')).outcome, SidecarOutcome.none);
  });

  test('a server that cannot be reached is a failure, to be retried', () async {
    server.failure = const NetworkException('blip');
    expect((await read()).outcome, SidecarOutcome.failed);
    server.failure = const AuthFailureException('401');
    expect((await read()).outcome, SidecarOutcome.failed);
  });

  test('a media name that could leave the folder is never sent', () async {
    for (final name in ['../etc/passwd', 'sub/clip.mp4', 'c:\\clip.mp4']) {
      final result = await SidecarReader(server)
          .read(canonicalUrl: watch, filename: name, language: 'en');
      expect(result.outcome, SidecarOutcome.none, reason: name);
    }
    expect(server.asked, isEmpty);
  });
}

class _FakeServer implements MeTubeApi {
  final texts = <String, String>{};
  final asked = <String>[];
  MTApiException? failure;

  @override
  Future<String> fetchText(String serverFilename, {int maxBytes = 0}) async {
    asked.add(serverFilename);
    if (failure case final e?) throw e;
    return texts[serverFilename] ?? (throw const NoApiException());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
