import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

import 'fake_api.dart';

/// Field report 2026-10-15: yt-dlp fetches a clip's subtitles, video and
/// audio one by one, and each reads "finished" in the server's queue under
/// its own file, deleted once the streams are merged. The app took the
/// first of them for the clip: Super stopped following too early, and Lite
/// went to pull a file that was about to vanish (a 404, "no MeTube API").
void main() {
  const inputUrl = 'https://youtu.be/dQw4w9WgXcQ';
  const canonical = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';

  Map<String, dynamic> row(String status, String file, {double? percent}) => {
    'id': 'dQw4w9WgXcQ',
    'title': 'clip',
    'url': canonical,
    'status': status,
    'filename': file,
    'percent': ?percent,
  };

  test('a finished stream in the queue is not the finished clip', () async {
    final api = FakeApi(
      historyScript: [
        historyWith(),
        historyWith(queue: [row('finished', 'clip [x].en.vtt', percent: 100)]),
        historyWith(
          queue: [row('downloading', 'clip [x].f399.mp4', percent: 40)],
        ),
        historyWith(
          queue: [row('finished', 'clip [x].f399.mp4', percent: 100)],
        ),
        historyWith(done: [row('finished', 'clip [x].mp4')]),
      ],
    );
    final engine = DownloadEngine(
      api: api,
      policy: DeletePolicy.keepOnServer,
      pullToDevice: false,
      pollInterval: Duration.zero,
      maxPollAttempts: 10,
      savePathBuilder: (t, f) => throw StateError('no path in server mode'),
      shortLinkResolver: ShortLinkResolver(redirectStep: (_) async => null),
    );
    addTearDown(engine.dispose);
    final progress = <double>[];
    engine.updates.listen((t) {
      if (t.phase == TaskPhase.polling && t.progress > 0) {
        progress.add(t.progress);
      }
    });

    final task = engine.submit(inputUrl, Quality.best);
    final result = await engine.updates
        .firstWhere((t) => t.id == task.id && t.isFinished)
        .timeout(const Duration(seconds: 5));

    expect(result.serverFilename, 'clip [x].mp4');
    // The subtitles' 100% and a finished stream's 100% are not progress.
    expect(progress, [0.4]);
  });
}
