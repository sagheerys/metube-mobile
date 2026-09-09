import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/features/library/library_models.dart';
import 'package:metube_super/features/playlists/playlists_providers.dart';
import 'package:mt_core/mt_core.dart';

SavedPlaylist _playlist(
  String name, {
  bool pinned = false,
  DateTime? lastPlayed,
  DateTime? created,
}) => SavedPlaylist(
  name: name,
  pinned: pinned,
  lastPlayedAt: lastPlayed,
  createdAt: created ?? DateTime(2026),
);

LibraryItem _item(
  String url, {
  bool favorite = false,
  String? localPath,
  DateTime? at,
}) => LibraryItem(
  canonicalUrl: url,
  title: url,
  favorite: favorite,
  localPath: localPath,
  timestamp: at,
  onServer: true,
);

void main() {
  group('ordering the playlists', () {
    test('pinned first, whenever they were last played', () {
      final sorted = sortPlaylists([
        _playlist('حديثة', lastPlayed: DateTime(2026, 9)),
        _playlist('مثبتة', pinned: true, lastPlayed: DateTime(2020)),
      ]);
      expect(sorted.first.name, 'مثبتة');
    });

    test('ordered by last played, not by creation date', () {
      final sorted = sortPlaylists([
        _playlist(
          'أُنشئت أخيراً',
          created: DateTime(2026, 9),
          lastPlayed: DateTime(2026, 1),
        ),
        _playlist(
          'شُغّلت اليوم',
          created: DateTime(2020),
          lastPlayed: DateTime(2026, 9),
        ),
      ]);
      expect(sorted.first.name, 'شُغّلت اليوم');
    });

    test('with no last played, the creation date is used', () {
      final sorted = sortPlaylists([
        _playlist('قديمة', created: DateTime(2020)),
        _playlist('جديدة', created: DateTime(2026, 8)),
      ]);
      expect(sorted.map((p) => p.name), ['جديدة', 'قديمة']);
    });

    test('the original list is not modified', () {
      final input = [
        _playlist('أ', created: DateTime(2020)),
        _playlist('ب', pinned: true),
      ];
      sortPlaylists(input);
      expect(input.first.name, 'أ');
    });
  });

  group('the smart playlists', () {
    final items = [
      _item('u1', favorite: true, at: DateTime(2026, 9, 1)),
      _item('u2', localPath: '/sd/2.mp4', at: DateTime(2026, 8, 30)),
      _item('u3', at: DateTime(2026, 8, 25)),
      _item(
        'u4',
        favorite: true,
        localPath: '/sd/4.mp4',
        at: DateTime(2026, 7),
      ),
    ];

    test('favourites collects only what is marked, newest first', () {
      final lists = buildSmartLists(items);
      final favorites = lists.firstWhere(
        (l) => l.kind == SmartListKind.favorites,
      );
      expect(favorites.items.map((i) => i.canonicalUrl), ['u1', 'u4']);
    });

    test('offline collects what has a local path', () {
      final offline = buildSmartLists(items)
          .firstWhere((l) => l.kind == SmartListKind.offline);
      expect(offline.items.map((i) => i.canonicalUrl), ['u2', 'u4']);
    });

    test('recently added is ordered descending and capped', () {
      final many = [
        for (var i = 0; i < 40; i++)
          _item('u$i', at: DateTime(2026, 1, 1).add(Duration(days: i))),
      ];
      final latest = buildSmartLists(many)
          .firstWhere((l) => l.kind == SmartListKind.latest);
      expect(latest.count, latestSmartListSize);
      expect(latest.items.first.canonicalUrl, 'u39');
    });

    test('an empty library gives three empty playlists, not a crash', () {
      final lists = buildSmartLists(const []);
      expect(lists.length, 3);
      expect(lists.every((l) => l.count == 0), isTrue);
    });
  });
}
