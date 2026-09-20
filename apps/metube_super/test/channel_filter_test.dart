import 'package:flutter_test/flutter_test.dart';
import 'package:metube_super/features/library/library_models.dart';
import 'package:metube_super/features/library/library_providers.dart';

/// **Filtering and searching by the channel** (م-73).
///
/// The channel name has always arrived in `/history` and has always been
/// printed on the card, and was usable for nothing: search covered the
/// title alone and no filter existed, so "show me everything from this
/// channel" could not be asked. Subscriptions made that gap the obvious
/// one — the whole point of following a channel is the channel.
void main() {
  LibraryItem item(String url, {required String title, String? uploader}) =>
      LibraryItem(
        canonicalUrl: url,
        title: title,
        uploader: uploader,
        onServer: true,
      );

  final items = [
    item(
      'u1',
      title: 'Backups that actually restore',
      uploader: 'Homelab Hour',
    ),
    item('u2', title: 'Pour-over at home', uploader: 'The Kitchen Notebook'),
    item('u3', title: 'Cold brew', uploader: 'The Kitchen Notebook'),
    item('u4', title: 'A clip about a homelab', uploader: 'Road Lens'),
    item('u5', title: 'No channel at all'),
  ];

  group('the channel filter', () {
    test('keeps only that channel', () {
      final view = buildLibraryView(items, channel: 'The Kitchen Notebook');
      expect(view.map((i) => i.canonicalUrl), ['u2', 'u3']);
    });

    test('an item with no channel is never swept in', () {
      final view = buildLibraryView(items, channel: 'Road Lens');
      expect(view.single.canonicalUrl, 'u4');
    });

    test('a blank name means every channel, NOT the items that have none — a '
        'filter one typo away from hiding the whole library is the wrong '
        'default', () {
      expect(buildLibraryView(items, channel: '   ').length, items.length);
      expect(buildLibraryView(items, channel: '').length, items.length);
    });

    test('case and stray spaces do not split one channel in two', () {
      // The name comes from the server verbatim, and a yt-dlp upgrade can
      // change its spacing between one download and the next.
      final view = buildLibraryView(items, channel: '  homelab hour ');
      expect(view.single.canonicalUrl, 'u1');
    });

    test('null means every channel, as before', () {
      expect(buildLibraryView(items).length, items.length);
    });

    test('it combines with the other filters rather than replacing them', () {
      final view = buildLibraryView(
        items,
        channel: 'The Kitchen Notebook',
        query: 'cold',
      );
      expect(view.single.canonicalUrl, 'u3');
    });
  });

  group('search covers the channel', () {
    test('a channel name finds its clips, though no title contains it', () {
      final view = buildLibraryView(items, query: 'kitchen');
      expect(view.map((i) => i.canonicalUrl), ['u2', 'u3']);
    });

    test('a word in a title still finds it', () {
      expect(
        buildLibraryView(items, query: 'pour-over').single.canonicalUrl,
        'u2',
      );
    });

    test('a word matching both a title and a channel returns both', () {
      // "homelab" is the channel of u1 and a word in the title of u4.
      final view = buildLibraryView(items, query: 'homelab');
      expect(view.map((i) => i.canonicalUrl), ['u1', 'u4']);
    });

    test('an item with no channel does not crash the search', () {
      expect(
        buildLibraryView(items, query: 'no channel').single.canonicalUrl,
        'u5',
      );
    });
  });

  test('an active channel counts as one filter, for the sort badge', () {
    // Guards the badge that tells the user a filter is on: without the
    // count, a channel filter set from an item sheet is invisible.
    const none = LibraryViewOptions();
    expect(none.activeFilters, 0);
    expect(none.copyWith(channel: () => 'Homelab Hour').activeFilters, 1);
  });

  test('toggling the same channel clears it', () {
    const options = LibraryViewOptions(channel: 'Homelab Hour');
    expect(options.copyWith(channel: () => null).channel, isNull);
  });
}
