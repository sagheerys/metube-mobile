import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/features/library/library_models.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_ui/mt_ui.dart' show MTMediaLocation;

void main() {
  final items = [
    LibraryItem(
      canonicalUrl: 'https://youtu.be/aaaaaaaaaaa',
      title: 'خطبة الجمعة',
      timestamp: DateTime(2026, 9, 1),
      sizeBytes: 300,
      onServer: true,
    ),
    LibraryItem(
      canonicalUrl: 'https://youtu.be/bbbbbbbbbbb',
      title: 'أنشودة الصباح',
      timestamp: DateTime(2026, 8, 1),
      sizeBytes: 100,
      onServer: true,
      localPath: '/x/a.mp3',
      isAudio: true,
      favorite: true,
    ),
    LibraryItem(
      canonicalUrl: 'https://vimeo.com/1',
      title: 'وثائقي البحار',
      timestamp: DateTime(2026, 7, 1),
      sizeBytes: 200,
      localPath: '/x/b.mp4',
      tags: const ['وثائقي'],
    ),
  ];

  group("buildLibraryView: the merged library's logic", () {
    test('the default: everything, newest first', () {
      final result = buildLibraryView(items);
      expect(result.map((i) => i.title).first, 'خطبة الجمعة');
      expect(result, hasLength(3));
    });

    test('the favourites filter', () {
      final result = buildLibraryView(items, scope: LibraryScope.favorites);
      expect(result.single.title, 'أنشودة الصباح');
    });

    test('the offline and server filters', () {
      expect(
        buildLibraryView(items, scope: LibraryScope.offline),
        hasLength(2),
      );
      expect(
        buildLibraryView(items, scope: LibraryScope.onServer),
        hasLength(2),
      );
    });

    test('the audio and video type filter', () {
      expect(
        buildLibraryView(items, type: MediaTypeFilter.audio),
        hasLength(1),
      );
      expect(
        buildLibraryView(items, type: MediaTypeFilter.video),
        hasLength(2),
      );
    });

    test('live search by title', () {
      expect(buildLibraryView(items, query: 'أنشودة').single.isAudio, isTrue);
      expect(buildLibraryView(items, query: 'غير موجود'), isEmpty);
    });

    test('filtering by a tag', () {
      expect(
        buildLibraryView(items, tags: {'وثائقي'}).single.title,
        'وثائقي البحار',
      );
    });

    test('compound tag filtering: inclusion is OR, and exclusion wins', () {
      // Inclusion widens: two tags means everything carrying either of
      // them.
      expect(
        buildLibraryView(items, tags: {'وثائقي', 'أناشيد'}).length,
        greaterThanOrEqualTo(1),
      );
      // Exclusion subtracts the item even when another tag includes it: an
      // explicit intention.
      expect(
        buildLibraryView(items, tags: {'وثائقي'}, excludedTags: {'وثائقي'}),
        isEmpty,
      );
      // Exclusion alone with no inclusion: everything except the carriers
      // of that tag.
      final withoutDoc = buildLibraryView(items, excludedTags: {'وثائقي'});
      expect(withoutDoc.any((i) => i.title == 'وثائقي البحار'), isFalse);
      expect(withoutDoc, isNotEmpty);
    });

    test('sorting by size and by name', () {
      expect(
        buildLibraryView(items, sort: LibrarySort.largest).first.sizeBytes,
        300,
      );
      expect(
        buildLibraryView(items, sort: LibrarySort.nameAZ).first.title,
        'أنشودة الصباح',
      );
    });

    test('the location badge', () {
      expect(items[0].location, MTMediaLocation.onServer);
      expect(items[1].location, MTMediaLocation.both);
      expect(items[2].location, MTMediaLocation.offline);
    });
  });

  group('LibraryItem.fromHistory', () {
    test('detecting audio from quality=audio', () {
      final item = LibraryItem.fromHistory(
        HistoryItem.fromJson({
          'url': 'https://soundcloud.com/a/t',
          'title': 'مقطع',
          'quality': 'audio',
          'status': 'finished',
        }),
      );
      expect(item.isAudio, isTrue);
      expect(item.onServer, isTrue);
    });

    test('the platform is derived from the canonical URL', () {
      expect(items[0].platform, MediaPlatform.youtube);
      expect(items[2].platform, MediaPlatform.vimeo);
    });
  });

  /// **The platform filter in Super** (requested 2026-09-08): the same
  /// logic as Lite, with the choice in the sort sheet rather than a third
  /// chip row.
  group('filtering by platform', () {
    test('only the chosen platform remains', () {
      final result = buildLibraryView(items, platform: MediaPlatform.youtube);
      expect(result, hasLength(2));
      expect(result.every((i) => i.platform == MediaPlatform.youtube), isTrue);
    });

    test('with no platform, everything: null is not the unknown platform', () {
      expect(buildLibraryView(items, platform: null), hasLength(3));
      expect(buildLibraryView(items, platform: MediaPlatform.other), isEmpty);
    });

    test(
      'the platform composes with the other filters rather than replacing them',
      () {
        final result = buildLibraryView(
          items,
          platform: MediaPlatform.youtube,
          scope: LibraryScope.favorites,
        );
        expect(result.map((i) => i.title), ['أنشودة الصباح']);
      },
    );

    test('the counters: the largest first and unknown last', () {
      final counts = platformCounts([
        ...items,
        LibraryItem(canonicalUrl: 'file:///x/y.mp4', title: 'مجهول'),
        LibraryItem(canonicalUrl: 'file:///x/z.mp4', title: 'مجهول ٢'),
        LibraryItem(canonicalUrl: 'file:///x/w.mp4', title: 'مجهول ٣'),
      ]);
      expect(counts.first.key, MediaPlatform.youtube);
      expect(counts.first.value, 2);
      // Three unknown items make it the largest group, and it still stays
      // last.
      expect(counts.last.key, MediaPlatform.other);
      expect(counts.last.value, 3);
    });
  });

  group('helpers', () {
    test('fromOfflineOnly takes the title from the filename', () {
      final item = LibraryItem.fromOfflineOnly(
        'https://youtu.be/ccccccccccc',
        '/storage/emulated/0/Download/MeTube_Super/درس التجويد_120000.mp4',
      );
      expect(item.title, 'درس التجويد_120000');
      expect(item.isAudio, isFalse);
      expect(item.location, MTMediaLocation.offline);
    });
  });
}
