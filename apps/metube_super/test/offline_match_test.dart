import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/di.dart';
import 'package:metube_super/features/library/library_providers.dart';
import 'package:metube_super/features/settings/settings_state.dart';
import 'package:mt_core/mt_core.dart';

/// **Defect found 2026-09-08: one file under ten items.**
///
/// "I made a single clip available offline, played the fourth clip, and the
/// first one played." The measured cause: Facebook puts the id in the query
/// (`watch/?v=…`) rather than the path, so `UrlKit.longestNumericId`
/// returned empty and matching fell through to the normalisation rank.
/// Normalisation strips the query, so every Facebook URL collapsed to
/// `facebook.com/watch`, and the offline index gave that one item's file to
/// every Facebook item, with the external player opening the wrong file.
void main() {
  const fb1 = 'https://m.facebook.com/watch/?v=1619243166301797&_rdr';
  const fb2 = 'https://m.facebook.com/watch/?v=2657266731405287&_rdr';
  const fb3 = 'https://m.facebook.com/watch/?v=1900817477558376&_rdr';

  HistoryItem item(String url, String name) => HistoryItem(
    id: url,
    canonicalUrl: url,
    title: name,
    filename: '$name.mp4',
    status: ItemStatus.completed,
  );

  late MemoryKeyValueStore store;

  ProviderContainer containerWith() {
    store = MemoryKeyValueStore();
    final container = ProviderContainer(
      overrides: [
        keyValueStoreProvider.overrideWithValue(store),
        secretStoreProvider.overrideWithValue(MemorySecretStore()),
        prefsMutexProvider.overrideWithValue(PrefsMutex()),
        initialSettingsProvider.overrideWithValue(const SuperSettings()),
        historyProvider.overrideWith(
          (ref) async => HistoryResponse(
            done: [
              item(fb1, 'الأول'),
              item(fb2, 'الثاني'),
              item(fb3, 'الثالث'),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  Future<void> seed(ProviderContainer c, Map<String, String> offline) async {
    final index = c.read(offlineIndexProvider);
    for (final e in offline.entries) {
      await index.put(e.key, e.value);
    }
  }

  test('عنصر واحد دون اتصال ⇒ وحده يحمل مساراً محلياً', () async {
    final container = containerWith();
    await seed(container, const {fb1: '/media/الأول.mp4'});

    final items = await container.read(libraryItemsProvider.future);
    final byTitle = {for (final i in items) i.title: i};

    expect(byTitle['الأول']?.localPath, '/media/الأول.mp4');
    // **The guard**: before the fix the second and third carried the same
    // path, so both showed an "external player" button and played the first
    // one's clip.
    expect(byTitle['الثاني']?.localPath, isNull);
    expect(byTitle['الثالث']?.localPath, isNull);
  });

  test('لا يتكرر ملفٌ واحد تحت عنصرين مهما تصادمت المطابقة', () async {
    final container = containerWith();
    await seed(container, const {fb1: '/media/x.mp4'});

    final items = await container.read(libraryItemsProvider.future);
    final paths = [for (final i in items) i.localPath].nonNulls.toList();
    expect(
      paths.toSet(),
      hasLength(paths.length),
      reason: 'كل مسار محلي لعنصر واحد لا أكثر',
    );
  });

  test('كلٌّ دون اتصال ⇒ كلٌّ بملفه هو', () async {
    final container = containerWith();
    await seed(container, const {
      fb1: '/media/1.mp4',
      fb2: '/media/2.mp4',
      fb3: '/media/3.mp4',
    });

    final items = await container.read(libraryItemsProvider.future);
    final byTitle = {for (final i in items) i.title: i};
    expect(byTitle['الأول']?.localPath, '/media/1.mp4');
    expect(byTitle['الثاني']?.localPath, '/media/2.mp4');
    expect(byTitle['الثالث']?.localPath, '/media/3.mp4');
    expect(items, hasLength(3), reason: 'ولا عنصر «محلي فقط» زائد');
  });

  /// The fuzzy matching itself is still needed: an entered URL can differ
  /// in shape from `/history`'s canonical one, so the cure must not be to
  /// abolish it.
  test('صيغة مختلفة لنفس المقطع ما زالت تتطابق', () async {
    final container = containerWith();
    await seed(container, const {
      'https://www.facebook.com/watch/?v=1619243166301797': '/media/1.mp4',
    });

    final items = await container.read(libraryItemsProvider.future);
    final byTitle = {for (final i in items) i.title: i};
    expect(byTitle['الأول']?.localPath, '/media/1.mp4');
    expect(byTitle['الثاني']?.localPath, isNull);
  });
}
