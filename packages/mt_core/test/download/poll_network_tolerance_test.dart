import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

import 'fake_api.dart';

/// **Field report 2026-09-13 (Super):** leave the app while the server is
/// still downloading, and the task was reported failed although the server
/// finished the file. The poll gave up on the first failed `/history`
/// request, which is exactly what a frozen or network-cut app produces.
///
/// In every script below, call 0 is the snapshot taken before the add, so
/// the poll itself starts at call 1.
void main() {
  const inputUrl = 'https://youtu.be/dQw4w9WgXcQ';
  const canonical = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';

  final running = historyWith();
  final done = historyWith(
    done: [
      {
        'id': 'dQw4w9WgXcQ',
        'title': 'clip',
        'url': canonical,
        'status': 'finished',
        'filename': 'clip.mp4',
      },
    ],
  );

  /// Super's engine: keeps files on the server and never pulls.
  DownloadEngine superEngine(FakeApi api, {int? tolerance}) => DownloadEngine(
    api: api,
    policy: DeletePolicy.keepOnServer,
    pullToDevice: false,
    pollInterval: Duration.zero,
    maxPollAttempts: 10,
    pollNetworkTolerance: tolerance ?? 0,
    savePathBuilder: (t, f) => throw StateError('no path in server mode'),
    shortLinkResolver: ShortLinkResolver(redirectStep: (_) async => null),
  );

  Future<DownloadTask> finished(DownloadEngine engine, String id) => engine
      .updates
      .firstWhere((t) => t.id == id && t.isFinished)
      .timeout(const Duration(seconds: 5));

  void failOn(FakeApi api, Set<int> calls) => api.onHistoryFetch = (call) {
    if (calls.contains(call)) throw const NetworkException('app frozen');
  };

  test('a network failure mid-poll is survived and the task completes', () async {
    final api = FakeApi(historyScript: [running, running, done]);
    failOn(api, {1});
    final engine = superEngine(api, tolerance: 2);
    addTearDown(engine.dispose);

    final task = engine.submit(inputUrl, Quality.best);
    final result = await finished(engine, task.id);

    expect(result.phase, TaskPhase.completed);
  });

  test("tolerance 0, Lite's rule, still fails on the first network error", () async {
    final api = FakeApi(historyScript: [running, running, done]);
    failOn(api, {1});
    final engine = superEngine(api);
    addTearDown(engine.dispose);

    final task = engine.submit(inputUrl, Quality.best);
    final result = await finished(engine, task.id);

    expect(result.phase, TaskPhase.failed);
    expect(result.error, isA<NetworkException>());
  });

  test('more failures in a row than tolerated fail the task', () async {
    final api = FakeApi(historyScript: [running, running, running, running, done]);
    failOn(api, {1, 2, 3});
    final engine = superEngine(api, tolerance: 2);
    addTearDown(engine.dispose);

    final task = engine.submit(inputUrl, Quality.best);
    final result = await finished(engine, task.id);

    expect(result.phase, TaskPhase.failed);
    expect(result.error, isA<NetworkException>());
  });

  test('a successful request resets the count of failures in a row', () async {
    final api = FakeApi(
      historyScript: [running, running, running, running, running, running, done],
    );
    failOn(api, {1, 2, 4, 5});
    final engine = superEngine(api, tolerance: 2);
    addTearDown(engine.dispose);

    final task = engine.submit(inputUrl, Quality.best);
    final result = await finished(engine, task.id);

    expect(result.phase, TaskPhase.completed);
  });

  test('cancelling during a failure streak still cancels', () async {
    final api = FakeApi(historyScript: [running]);
    late final DownloadEngine engine;
    late final String id;
    api.onHistoryFetch = (call) {
      if (call == 0) return;
      if (call == 3) engine.cancel(id);
      throw const NetworkException('server gone');
    };
    engine = superEngine(api, tolerance: 100);
    addTearDown(engine.dispose);

    id = engine.submit(inputUrl, Quality.best).id;
    final result = await finished(engine, id);

    expect(result.phase, TaskPhase.cancelled);
  });
}
