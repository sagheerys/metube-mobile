import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

import 'fake_api.dart';

/// **Work before the add, and subtitles never taken for the clip**
/// (2026-09-30). Super fetches a transcript before adding a clip, because
/// MeTube keys finished jobs by URL alone.
void main() {
  const canonical = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';

  Map<String, dynamic> done({
    String type = 'video',
    String filename = 'clip.mp4',
  }) => {
    'url': canonical,
    'status': 'finished',
    'download_type': type,
    'filename': filename,
  };

  DownloadEngine superEngine(
    FakeApi api, {
    Future<void> Function(DownloadTask)? beforeAdd,
    List<String>? log,
  }) => DownloadEngine(
    api: api,
    policy: DeletePolicy.keepOnServer,
    pullToDevice: false,
    pollInterval: Duration.zero,
    maxPollAttempts: 5,
    savePathBuilder: (_, _) => throw StateError('no pull'),
    shortLinkResolver: ShortLinkResolver(redirectStep: (_) async => null),
    beforeAdd: beforeAdd,
    onLog: log?.add,
  );

  Future<DownloadTask> finished(DownloadEngine engine, String id) => engine
      .updates
      .firstWhere((t) => t.id == id && t.isFinished)
      .timeout(const Duration(seconds: 5));

  test(
    'the hook runs before the add, with the task, and the add follows',
    () async {
      final api = FakeApi(
        historyScript: [
          historyWith(),
          historyWith(done: [done()]),
        ],
      );
      final order = <String>[];
      api.beforeAdd = () async => order.add('add');
      final engine = superEngine(
        api,
        beforeAdd: (task) async {
          order.add('hook ${task.isBatchMember}');
          expect(
            api.adds,
            isEmpty,
            reason: 'the clip is not on the server yet',
          );
        },
      );

      final task = engine.submit(canonical, Quality.best);
      final result = await finished(engine, task.id);

      expect(order, ['hook false', 'add']);
      expect(result.phase, TaskPhase.completed);
      await engine.dispose();
    },
  );

  test(
    'a failing hook delays nothing further and never stops the add',
    () async {
      final api = FakeApi(
        historyScript: [
          historyWith(),
          historyWith(done: [done()]),
        ],
      );
      final log = <String>[];
      final engine = superEngine(
        api,
        log: log,
        beforeAdd: (_) async => throw StateError('transcripts broke'),
      );

      final task = engine.submit(canonical, Quality.best);
      final result = await finished(engine, task.id);

      expect(result.phase, TaskPhase.completed);
      expect(api.adds, hasLength(1));
      expect(log.any((l) => l.contains('transcripts broke')), isTrue);
      await engine.dispose();
    },
  );

  test(
    'a subtitles job under the same URL is never taken for the clip',
    () async {
      // If cleaning up a transcript failed, its entry is still in `done` when
      // the clip is polled for. Taken for the clip, Super would name an .srt
      // as the download, and Lite would pull it and delete it.
      final api = FakeApi(
        historyScript: [
          historyWith(),
          historyWith(
            done: [done(type: 'captions', filename: 'clip.en.srt')],
          ),
          historyWith(
            done: [
              done(type: 'captions', filename: 'clip.en.srt'),
              done(),
            ],
          ),
        ],
      );
      final engine = superEngine(api);

      final task = engine.submit(canonical, Quality.best);
      final result = await finished(engine, task.id);

      expect(result.serverFilename, 'clip.mp4');
      await engine.dispose();
    },
  );
}
