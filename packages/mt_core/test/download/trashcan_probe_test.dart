import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

import 'fake_api.dart';

/// **`DELETE_FILE_ON_TRASHCAN`, the silent one** (audit 2026-09-19).
///
/// It is off by default in MeTube — read from its source: the file is
/// removed only when that variable is true. Lite's promise rests on it, and
/// without it everything looks right: the row goes, the app reports
/// success, the library is correct, and the disk fills up for months.
///
/// The probe asks one question after a cleanup the app believes worked: is
/// the file still being served? The care in these tests is that it must
/// **never guess**. A warning shown wrongly sends someone to change a
/// setting that was already right.
void main() {
  late FakeApi api;
  late MemoryKeyValueStore store;
  late TrashcanProbe probe;

  setUp(() {
    api = FakeApi();
    store = MemoryKeyValueStore();
    probe = TrashcanProbe(api: api, store: store, mutex: PrefsMutex());
  });

  test(
    'a file still served after its delete means the server keeps it',
    () async {
      expect(await probe.check('clip.mp4'), isTrue);
      expect(await probe.serverKeepsFiles, isTrue);
    },
  );

  test('a file that is gone means the server is configured right', () async {
    api.missingFiles.add('clip.mp4');

    expect(await probe.check('clip.mp4'), isFalse);
    expect(await probe.serverKeepsFiles, isFalse);
  });

  test('fixing the container clears the warning', () async {
    await probe.check('clip.mp4');
    expect(await probe.serverKeepsFiles, isTrue);

    // The same probe, after the setting was turned on.
    api.missingFiles.add('clip.mp4');
    await probe.check('clip.mp4');

    expect(
      await probe.serverKeepsFiles,
      isFalse,
      reason: 'the warning goes with its cause',
    );
  });

  test('no filename is no answer, and writes nothing', () async {
    expect(await probe.check(null), isFalse);
    expect(await probe.check(''), isFalse);
    expect(await store.get(TrashcanProbe.prefsKey), isNull);
  });

  test(
    'a flag already set is not disturbed by an unanswerable check',
    () async {
      await probe.check('clip.mp4');

      expect(await probe.check(null), isFalse);
      expect(
        await probe.serverKeepsFiles,
        isTrue,
        reason: 'silence is not evidence that the container was fixed',
      );
    },
  );
}
