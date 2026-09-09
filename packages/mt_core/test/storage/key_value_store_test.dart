import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  group('MemoryKeyValueStore + TypedReads', () {
    test('typed writes and reads', () async {
      final store = MemoryKeyValueStore();
      await store.setString('s', 'نص');
      await store.setBool('b', true);
      await store.setInt('i', 7);
      await store.setDouble('d', 1.5);
      await store.setStringList('l', ['أ', 'ب']);

      expect(await store.getString('s'), 'نص');
      expect(await store.getBool('b'), isTrue);
      expect(await store.getInt('i'), 7);
      expect(await store.getDouble('d'), 1.5);
      expect(await store.getStringList('l'), ['أ', 'ب']);
      expect(await store.keys(), {'s', 'b', 'i', 'd', 'l'});
    });

    test('a typed read of the wrong type gives null, not a crash', () async {
      final store = MemoryKeyValueStore();
      await store.setString('x', 'not-bool');
      expect(await store.getBool('x'), isNull);
      expect(await store.getInt('x'), isNull);
    });

    test('remove deletes', () async {
      final store = MemoryKeyValueStore();
      await store.setString('k', 'v');
      await store.remove('k');
      expect(await store.get('k'), isNull);
    });
  });

  group('PrefsMutex', () {
    test('it serialises concurrent read-modify-write: no lost write', () async {
      final store = MemoryKeyValueStore();
      final mutex = PrefsMutex();

      Future<void> incrementNTimes(int n) async {
        for (var i = 0; i < n; i++) {
          await mutex.run(() async {
            final current = await store.getInt('counter') ?? 0;
            await Future<void>.delayed(Duration.zero); // the race window
            await store.setInt('counter', current + 1);
          });
        }
      }

      await Future.wait([incrementNTimes(50), incrementNTimes(50)]);
      expect(
        await store.getInt('counter'),
        100,
        reason: 'بلا قفل تضيع كتابات في نافذة السباق',
      );
    });
  });
}
