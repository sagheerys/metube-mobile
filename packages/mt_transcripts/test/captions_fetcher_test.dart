import 'package:mt_core/mt_core.dart';
import 'package:mt_transcripts/mt_transcripts.dart';
import 'package:test/test.dart';

/// **Fetching subtitles must never cost the owner a clip.** MeTube keys
/// finished jobs by URL alone, so a subtitles job for a clip already in the
/// history replaces its entry (measured on a real server 2026-09-29). The
/// tests marked GUARD fail if any of the three rules in [CaptionsFetcher]
/// is removed.
void main() {
  const id = 'jNQXAC9IVRw';
  const watch = 'https://www.youtube.com/watch?v=$id';
  const srtName = 'Me at the zoo [$id].en.srt';
  const srt = '1\n00:00:01,200 --> 00:00:03,360\nhere we are\n';

  HistoryItem row({
    String url = watch,
    String type = 'captions',
    String status = 'finished',
    String? filename = srtName,
    String? error,
  }) => HistoryItem.fromJson({
    'url': url,
    'download_type': type,
    'status': status,
    'filename': ?filename,
    'error': ?error,
  });

  late _FakeServer server;
  CaptionsFetcher fetcher() => CaptionsFetcher(
    server,
    wait: (_) async {},
    timeout: const Duration(seconds: 10),
  );

  setUp(() => server = _FakeServer()..texts[srtName] = srt);

  test(
    'the happy path: fetched, read, and the subtitles entry deleted',
    () async {
      server.script = [
        const HistoryResponse(), // the check before asking
        HistoryResponse(queue: [row(status: 'downloading', filename: null)]),
        HistoryResponse(done: [row()]),
      ];
      final result = await fetcher().fetch(
        'https://youtu.be/$id',
        language: 'en',
      );

      expect(result.outcome, CaptionsOutcome.fetched);
      expect(result.transcript!.canonicalUrl, watch);
      expect(result.transcript!.language, 'en');
      expect(result.transcript!.segments.single.text, 'here we are');
      expect(server.captionsAsked, [(watch, 'en')]);
      expect(server.deletes, ['$watch @ done']);
    },
  );

  test('GUARD: a clip already in the library is never asked for', () async {
    server.script = [
      HistoryResponse(
        done: [row(type: 'video', filename: 'Me at the zoo.mp4')],
      ),
    ];
    final result = await fetcher().fetch(watch, language: 'en');

    expect(result.outcome, CaptionsOutcome.alreadyOnServer);
    expect(server.captionsAsked, isEmpty);
    expect(server.deletes, isEmpty);
  });

  test(
    'GUARD: the check matches the video whatever form its URL takes',
    () async {
      for (final list in ['queue', 'pending', 'done']) {
        server = _FakeServer();
        final item = row(
          type: 'video',
          url: 'https://www.youtube.com/shorts/$id',
        );
        server.script = [
          HistoryResponse(
            queue: list == 'queue' ? [item] : const [],
            pending: list == 'pending' ? [item] : const [],
            done: list == 'done' ? [item] : const [],
          ),
        ];
        final result = await fetcher().fetch(
          'https://youtu.be/$id',
          language: 'en',
        );
        expect(result.outcome, CaptionsOutcome.alreadyOnServer, reason: list);
        expect(server.captionsAsked, isEmpty, reason: list);
      }
    },
  );

  test('GUARD: only YouTube links are fetched', () async {
    final result = await fetcher().fetch(
      'https://vimeo.com/76979871',
      language: 'en',
    );
    expect(result.outcome, CaptionsOutcome.unsupported);
    expect(server.historyReads, 0);
    expect(server.captionsAsked, isEmpty);
  });

  test(
    'GUARD: a video that arrives under the same URL is never deleted',
    () async {
      server.script = [
        const HistoryResponse(),
        HistoryResponse(
          done: [row(type: 'video', filename: 'Me at the zoo.mp4')],
        ),
      ];
      final result = await fetcher().fetch(watch, language: 'en');

      expect(result.outcome, CaptionsOutcome.failed);
      expect(server.deletes, isEmpty);
    },
  );

  test('a clip with no subtitles is "none", and its entry is still '
      'cleared', () async {
    server.script = [
      const HistoryResponse(),
      HistoryResponse(done: [row(filename: null)]),
    ];
    final result = await fetcher().fetch(watch, language: 'ar');

    expect(result.outcome, CaptionsOutcome.none);
    expect(server.deletes, ['$watch @ done']);
  });

  test('a failed job is reported and cleared', () async {
    server.script = [
      const HistoryResponse(),
      HistoryResponse(
        done: [row(status: 'error', error: 'HTTP Error 429')],
      ),
    ];
    final result = await fetcher().fetch(watch, language: 'en');

    expect(result.outcome, CaptionsOutcome.failed);
    expect(result.detail, contains('429'));
    expect(server.deletes, ['$watch @ done']);
  });

  test('a job that never finishes is cancelled, so it cannot land on the '
      'video later', () async {
    server.script = [
      const HistoryResponse(),
      HistoryResponse(queue: [row(status: 'downloading', filename: null)]),
    ];
    final result = await fetcher().fetch(watch, language: 'en');

    expect(result.outcome, CaptionsOutcome.failed);
    expect(server.deletes, ['$watch @ queue']);
  });

  test('the timeout is time: slow readings stop it sooner', () async {
    var now = DateTime(2026);
    server.script = [
      const HistoryResponse(),
      HistoryResponse(queue: [row(status: 'downloading', filename: null)]),
    ];
    final result = await CaptionsFetcher(
      server,
      wait: (_) async {},
      // The clock moves three seconds at every look: six per reading.
      clock: () => now = now.add(const Duration(seconds: 3)),
      timeout: const Duration(seconds: 10),
    ).fetch(watch, language: 'en');
    expect(result.outcome, CaptionsOutcome.failed);
    // The check, two readings, and the last look: not five readings.
    expect(server.historyReads, lessThan(6));
    expect(server.deletes, ['$watch @ queue']);
  });

  test(
    'when every reading failed, a last look still cancels the job',
    () async {
      server
        ..script = [
          const HistoryResponse(),
          HistoryResponse(queue: [row(status: 'downloading', filename: null)]),
        ]
        ..failReads = {2, 3, 4, 5, 6};
      final result = await fetcher().fetch(watch, language: 'en');
      expect(result.outcome, CaptionsOutcome.failed);
      expect(server.deletes, ['$watch @ queue']);
    },
  );

  test('one missed history reading does not abandon the job', () async {
    server
      ..script = [
        const HistoryResponse(),
        HistoryResponse(done: [row()]),
      ]
      ..failReadNumber = 2;
    final result = await fetcher().fetch(watch, language: 'en');

    expect(result.outcome, CaptionsOutcome.fetched);
  });

  test('an unreadable file still clears the entry', () async {
    server
      ..script = [
        const HistoryResponse(),
        HistoryResponse(done: [row()]),
      ]
      ..texts.clear();
    final result = await fetcher().fetch(watch, language: 'en');

    expect(result.outcome, CaptionsOutcome.failed);
    expect(server.deletes, ['$watch @ done']);
  });

  test('an empty subtitle file is "none"', () async {
    server
      ..script = [
        const HistoryResponse(),
        HistoryResponse(done: [row()]),
      ]
      ..texts[srtName] = '';
    final result = await fetcher().fetch(watch, language: 'en');
    expect(result.outcome, CaptionsOutcome.none);
  });
}

/// A MeTube server whose history follows a script, one response per read,
/// the last repeating. Every method the fetcher does not use throws.
class _FakeServer implements MeTubeApi {
  List<HistoryResponse> script = const [HistoryResponse()];
  int historyReads = 0;
  int? failReadNumber;
  Set<int> failReads = {};
  final captionsAsked = <(String, String)>[];
  final deletes = <String>[];
  final texts = <String, String>{};

  @override
  Future<HistoryResponse> fetchHistory() async {
    final n = ++historyReads;
    if (n == failReadNumber || failReads.contains(n)) {
      throw const NetworkException('blip');
    }
    return script[n - 1 < script.length ? n - 1 : script.length - 1];
  }

  @override
  Future<void> addCaptions(String url, {required String language}) async =>
      captionsAsked.add((url, language));

  @override
  Future<String> fetchText(String serverFilename, {int maxBytes = 0}) async {
    final text = texts[serverFilename];
    if (text == null) throw const NoApiException();
    return text;
  }

  @override
  Future<void> delete(
    List<String> canonicalUrls, {
    String where = 'done',
  }) async => deletes.add('${canonicalUrls.join(',')} @ $where');

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');
}
