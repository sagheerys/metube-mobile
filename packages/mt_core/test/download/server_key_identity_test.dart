import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

import 'fake_api.dart';

/// **Following the item by the key the server filed it under**.
///
/// Three field reports in two days had one shape: the clip downloaded
/// perfectly and the app never noticed, because MeTube files an item under
/// the URL yt-dlp ended at and we were watching the URL we sent. Reddit's
/// share links, then Vimeo's author-page links — and each fix was one more
/// platform on a list, never the end of the list.
///
/// The server already has an identity for the item: the key its lists are
/// indexed by. Straight after our own `/add`, the one thing that changed on
/// the server is ours, whatever it is called. These tests are about that
/// step being both **right** and **unwilling to guess**.
void main() {
  const sent = 'https://vimeo.com/hugodesousa/bestfriendswiththedevil';
  const filed = 'https://vimeo.com/1225400313';

  Map<String, dynamic> item(
    String url, {
    String status = 'finished',
    String? filename = 'Best Friends with the Devil [1225400313].mp4',
    String? error,
  }) => {'url': url, 'status': status, 'filename': ?filename, 'error': ?error};

  HistoryResponse history({
    List<Map<String, dynamic>> done = const [],
    List<Map<String, dynamic>> queue = const [],
  }) => HistoryResponse.fromJson({'done': done, 'queue': queue});

  DownloadEngine engineFor(FakeApi api) => DownloadEngine(
    api: api,
    policy: DeletePolicy.keepOnServer,
    savePathBuilder: (_, name) => '/tmp/$name',
    pullToDevice: false,
    // Six turns is above `identifyTurns`, so a task that gives up on the
    // key still gets its fallback turns before the ceiling.
    maxPollAttempts: 6,
    pollInterval: const Duration(milliseconds: 1),
    shortLinkResolver: ShortLinkResolver(redirectStep: (_) async => null),
  );

  Future<DownloadTask> finished(DownloadEngine engine, String id) => engine
      .updates
      .firstWhere((t) => t.id == id && t.isFinished)
      .timeout(const Duration(seconds: 5));

  test('the clip is followed under the URL the server chose, which is not '
      'the one we sent — the Vimeo report, reproduced', () async {
    final api = FakeApi(
      historyScript: [
        history(), // before the add: an empty server
        history(done: [item(filed)]), // our add, filed under its number
      ],
    );
    final engine = engineFor(api);
    final task = engine.submit(sent, Quality.best);
    final result = await finished(engine, task.id);

    expect(result.phase, TaskPhase.completed);
    expect(
      result.canonicalUrl,
      filed,
      reason: 'وهذا ما يجعل إشعار الوصول يعرف أن المقطع لنا',
    );
    expect(
      UrlKit.urlsMatch(filed, sent),
      isFalse,
      reason: 'بلا المفتاح لا مطابقة',
    );
  });

  test('the key is known before the download ends, so a cancellation can '
      'reach the right item', () async {
    final api = FakeApi(
      historyScript: [
        history(),
        history(queue: [item(filed, status: 'downloading', filename: null)]),
        history(queue: [item(filed, status: 'downloading', filename: null)]),
      ],
    );
    final engine = engineFor(api);
    final task = engine.submit(sent, Quality.best);
    api.onHistoryFetch = (call) {
      if (call == 1) engine.cancel(task.id);
    };

    final result = await finished(engine, task.id);
    expect(result.phase, TaskPhase.cancelled);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(api.deletes, hasLength(1));
    expect(api.deletes.single.$1.single, filed);
    expect(api.deletes.single.$2, 'queue');
  });

  group('it refuses to guess', () {
    test('two things changing at once is somebody else on the same server, '
        'and the task falls back to matching by URL', () async {
      final other = 'https://www.instagram.com/reel/DT8qRtWDPc5/';
      final api = FakeApi(
        historyScript: [
          history(),
          // Ours arrived, and so did a download somebody else started.
          history(
            done: [
              item(filed),
              item(other, filename: 'theirs.mp4'),
            ],
          ),
          history(
            done: [
              item(filed),
              item(other, filename: 'theirs.mp4'),
            ],
          ),
        ],
      );
      final engine = engineFor(api);
      final task = engine.submit(sent, Quality.best);

      // No key is adopted, so nothing is claimed: the URL does not match
      // either item, and the task ends on the polling ceiling rather than
      // on a stranger's file.
      final result = await finished(engine, task.id);
      expect(result.phase, TaskPhase.failed);
      expect(result.error, isA<PollTimeoutException>());
      expect(
        result.canonicalUrl,
        isNull,
        reason: 'ولا يُسجَّل مفتاح لم نتأكد منه',
      );
    });

    test(
      'our own re-add of something already on the server counts as a '
      'change, so a stranger\'s new download is not mistaken for ours',
      () async {
        // The clip is already in `done`. We ask for it again, which moves it
        // rather than adding a key; if only NEW keys counted, the only
        // change visible would be the other person's download.
        final theirs = 'https://soundcloud.com/someone/track';
        final api = FakeApi(
          historyScript: [
            history(done: [item(filed)]),
            history(
              queue: [item(filed, status: 'downloading', filename: null)],
              done: [item(theirs, filename: 'theirs.mp4')],
            ),
            history(
              queue: [item(filed, status: 'downloading', filename: null)],
              done: [item(theirs, filename: 'theirs.mp4')],
            ),
          ],
        );
        final engine = engineFor(api);
        final task = engine.submit(sent, Quality.best);
        final result = await finished(engine, task.id);

        expect(result.phase, TaskPhase.failed);
        expect(
          result.canonicalUrl,
          isNot(theirs),
          reason: 'أخطر نتيجة ممكنة: تبنّي ملف شخص آخر، وفي Lite حذفه',
        );
      },
    );

    test('a history that could not be read identifies nothing, rather than '
        'treating an empty answer as an empty server', () async {
      final api = FakeApi(
        historyScript: [
          history(done: [item(filed)]),
        ],
      )..failHistoryOnce = true;
      final engine = engineFor(api);
      final task = engine.submit(sent, Quality.best);
      final result = await finished(engine, task.id);

      // Everything on the server would look new against an empty "before".
      expect(result.canonicalUrl, isNull);
      expect(result.phase, TaskPhase.failed);
    });
  });
}
