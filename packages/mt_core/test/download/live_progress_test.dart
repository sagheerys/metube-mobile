import 'dart:convert';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

import 'fake_api.dart';

/// Field report 2026-10-15 (Super): the progress of a download on the
/// server moved in jumps, 30, 60, 100, and a short clip went from nothing
/// to done at once, because it was only read from `/history` every few
/// seconds. The live channel now reports it as it happens.
void main() {
  const inputUrl = 'https://youtu.be/dQw4w9WgXcQ';
  const canonical = 'https://www.youtube.com/watch?v=dQw4w9WgXcQ';

  Map<String, dynamic> item(String status, {double? percent, String? file}) => {
    'id': 'dQw4w9WgXcQ',
    'title': 'clip',
    'url': canonical,
    'status': status,
    'percent': ?percent,
    'filename': ?file,
  };

  MTLiveUpdate update(String status, {double? percent, bool done = false}) =>
      MTLiveUpdate(
        HistoryItem.fromJson(item(status, percent: percent)),
        completed: done,
      );

  /// Super's engine with a poll far longer than the test may take: only
  /// the live channel can finish it in time.
  DownloadEngine engine(FakeApi api) => DownloadEngine(
    api: api,
    policy: DeletePolicy.keepOnServer,
    pullToDevice: false,
    pollInterval: const Duration(seconds: 30),
    maxPollAttempts: 10,
    savePathBuilder: (t, f) => throw StateError('no path in server mode'),
    shortLinkResolver: ShortLinkResolver(redirectStep: (_) async => null),
  );

  test('progress arrives as it happens, forward only, and done comes '
      'without waiting for the next read', () async {
    final api = FakeApi(
      historyScript: [
        historyWith(),
        historyWith(queue: [item('downloading', percent: 0)]),
        historyWith(done: [item('finished', file: 'clip.mp4')]),
      ],
    );
    final e = engine(api);
    addTearDown(e.dispose);
    final seen = <double>[];
    e.updates.listen((t) {
      if (t.phase == TaskPhase.polling && t.progress > 0) {
        seen.add(t.progress);
      }
    });

    final task = e.submit(inputUrl, Quality.best);
    await e.updates.firstWhere((t) => t.phase == TaskPhase.polling);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(api.liveListens, 1);

    api.live
      ..add(update('downloading', percent: 30))
      ..add(update('downloading', percent: 60))
      // The audio stream starts again from zero.
      ..add(update('downloading', percent: 10))
      // A stream finishing is not the clip finishing.
      ..add(update('finished', percent: 100))
      ..add(update('downloading', percent: 100));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(seen, [0.3, 0.6, 0.99]);

    api.live.add(update('finished', percent: 100, done: true));
    final result = await e.updates
        .firstWhere((t) => t.id == task.id && t.isFinished)
        .timeout(const Duration(seconds: 3));
    expect(result.phase, TaskPhase.completed);
    expect(result.serverFilename, 'clip.mp4');
  });

  group('reading a packet', () {
    test('an update sent as text inside the packet', () {
      final packet =
          '42${jsonEncode(['updated', jsonEncode(item('downloading', percent: 42.5))])}';
      final update = MTLiveUpdate.fromPacket(packet)!;
      expect(update.completed, isFalse);
      expect(update.item.canonicalUrl, canonical);
      expect(update.item.progress, closeTo(0.425, 1e-9));
    });

    test('the completion, sent as an object', () {
      final packet =
          '42${jsonEncode(['completed', item('finished', file: 'clip.mp4')])}';
      expect(MTLiveUpdate.fromPacket(packet)!.completed, isTrue);
    });

    test('anything else is passed over', () {
      expect(MTLiveUpdate.fromPacket('42["all",[[],[]]]'), isNull);
      expect(MTLiveUpdate.fromPacket('40{"sid":"x"}'), isNull);
      expect(MTLiveUpdate.fromPacket('42["updated",{broken'), isNull);
    });
  });
}
