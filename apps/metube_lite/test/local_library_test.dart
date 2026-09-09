import 'package:flutter_test/flutter_test.dart';
import 'package:metube_lite/features/downloads_library/local_item.dart';
import 'package:mt_core/mt_core.dart';

LocalItem item(
  String name, {
  String? url,
  int size = 1000,
  DateTime? modified,
  bool favorite = false,
  Duration? duration,
  double? aspectRatio,
  String? title,
}) => LocalItem(
  key: url ?? '$liteMediaDir/$name',
  path: '$liteMediaDir/$name',
  canonicalUrl: url,
  title: title ?? LocalItem.titleFromFilename(name),
  sizeBytes: size,
  modified: modified ?? DateTime(2026),
  favorite: favorite,
  duration: duration,
  aspectRatio: aspectRatio,
);

void main() {
  group('LocalItem', () {
    test('the default title drops the extension and the time stamp', () {
      expect(
        LocalItem.titleFromFilename('Golden Brown_035532.m4a'),
        'Golden Brown',
      );
      expect(LocalItem.titleFromFilename('بلا امتداد'), 'بلا امتداد');
      // A number at the end of a name is not a time stamp; that is six
      // digits after an underscore.
      expect(LocalItem.titleFromFilename('Episode_12.mp4'), 'Episode_12');
    });

    test('the media type comes from the extension', () {
      expect(item('a.m4a').isAudio, isTrue);
      expect(item('a.mp4').isAudio, isFalse);
      expect(isMediaFile('/x/a.txt'), isFalse);
      expect(isMediaFile('/x/a.webm'), isTrue);
    });

    test(
      'the platform is derived from the URL, and unknown is not a guess',
      () {
        expect(
          item('a.mp4', url: 'https://youtu.be/abc').platform,
          MediaPlatform.youtube,
        );
        expect(item('a.mp4').platform, MediaPlatform.other);
      },
    );

    test('shorts: portrait and at most 3 minutes; unknown is not a short', () {
      expect(
        item(
          'a.mp4',
          duration: const Duration(seconds: 40),
          aspectRatio: 0.56,
        ).isShortForm,
        isTrue,
      );
      expect(
        item(
          'a.mp4',
          duration: const Duration(minutes: 9),
          aspectRatio: 0.56,
        ).isShortForm,
        isFalse,
      );
      // Dimensions not yet known means it is not a short.
      expect(
        item('a.mp4', duration: const Duration(seconds: 40)).isShortForm,
        isFalse,
      );
      expect(
        item(
          'a.m4a',
          duration: const Duration(seconds: 40),
          aspectRatio: 0.56,
        ).isShortForm,
        isFalse,
      );
    });
  });

  group('buildLocalLibraryView', () {
    final items = [
      item(
        'one.mp4',
        url: 'https://youtu.be/1',
        size: 300,
        modified: DateTime(2026, 1, 3),
        title: 'Alpha',
      ),
      item(
        'two.m4a',
        url: 'https://soundcloud.com/x/y',
        size: 100,
        modified: DateTime(2026, 1, 1),
        favorite: true,
        title: 'Beta',
      ),
      item(
        'three.mp4',
        size: 200,
        modified: DateTime(2026, 1, 2),
        title: 'Gamma',
        duration: const Duration(seconds: 30),
        aspectRatio: 0.5,
      ),
    ];

    test('the default is newest first', () {
      expect(buildLocalLibraryView(items).map((i) => i.title), [
        'Alpha',
        'Gamma',
        'Beta',
      ]);
    });

    test('the favourites, audio and shorts filters', () {
      expect(
        buildLocalLibraryView(
          items,
          scope: LocalScope.favorites,
        ).map((i) => i.title),
        ['Beta'],
      );
      expect(
        buildLocalLibraryView(
          items,
          type: MediaTypeFilter.audio,
        ).map((i) => i.title),
        ['Beta'],
      );
      expect(
        buildLocalLibraryView(
          items,
          type: MediaTypeFilter.shorts,
        ).map((i) => i.title),
        ['Gamma'],
      );
    });

    test("the platform filter, which is Lite's alone", () {
      expect(
        buildLocalLibraryView(
          items,
          platform: MediaPlatform.youtube,
        ).map((i) => i.title),
        ['Alpha'],
      );
      expect(
        buildLocalLibraryView(
          items,
          platform: MediaPlatform.other,
        ).map((i) => i.title),
        ['Gamma'],
      );
    });

    test('searching by title is case-insensitive', () {
      expect(buildLocalLibraryView(items, query: 'BET').map((i) => i.title), [
        'Beta',
      ]);
    });

    test('sorting by size and by name', () {
      expect(
        buildLocalLibraryView(
          items,
          sort: LibrarySort.largest,
        ).map((i) => i.sizeBytes),
        [300, 200, 100],
      );
      expect(
        buildLocalLibraryView(
          items,
          sort: LibrarySort.nameZA,
        ).map((i) => i.title),
        ['Gamma', 'Beta', 'Alpha'],
      );
    });

    test('the filters compose', () {
      expect(
        buildLocalLibraryView(
          items,
          scope: LocalScope.favorites,
          type: MediaTypeFilter.video,
        ).isEmpty,
        isTrue,
      );
    });
  });

  group('platformCounts', () {
    test('the largest first, with Other last however many it holds', () {
      final counts = platformCounts([
        item('a.mp4'),
        item('b.mp4'),
        item('c.mp4'),
        item('d.mp4', url: 'https://youtu.be/1'),
        item('e.mp4', url: 'https://youtu.be/2'),
        item('f.mp4', url: 'https://www.tiktok.com/@a/video/1'),
      ]);
      expect(counts.map((e) => e.key), [
        MediaPlatform.youtube,
        MediaPlatform.tiktok,
        MediaPlatform.other,
      ]);
      expect(counts.map((e) => e.value), [2, 1, 3]);
    });

    test('an empty library shows no chips', () {
      expect(platformCounts(const []), isEmpty);
    });
  });
}
