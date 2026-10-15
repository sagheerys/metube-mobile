import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

import 'fake_api.dart';

/// Field report 2026-10-15: a failed download left only
/// "task failed: NoApiException" in the log, which could have come from
/// adding the link, from following it, or from pulling the file.
void main() {
  test('a failure is logged with the step it happened at', () async {
    final logs = <String>[];
    final api = FakeApi(historyScript: [historyWith()])
      ..beforeAdd = () async => throw const NoApiException('HTTP 404 at /add');
    final engine = DownloadEngine(
      api: api,
      policy: DeletePolicy.keepOnServer,
      pullToDevice: false,
      pollInterval: Duration.zero,
      savePathBuilder: (t, f) => throw StateError('no path in server mode'),
      shortLinkResolver: ShortLinkResolver(redirectStep: (_) async => null),
      onLog: logs.add,
    );
    addTearDown(engine.dispose);

    final task = engine.submit('https://youtu.be/dQw4w9WgXcQ', Quality.best);
    await engine.updates
        .firstWhere((t) => t.id == task.id && t.isFinished)
        .timeout(const Duration(seconds: 5));

    expect(
      logs,
      contains('task failed while adding: NoApiException: HTTP 404 at /add'),
    );
  });
}
