import 'package:flutter_test/flutter_test.dart';
import 'package:mt_media/mt_media.dart';

/// **Field report 2026-09-19:** "some audio clips have a cover, and it
/// shows inside the app but not in the player notification, nor on the
/// lock screen".
///
/// The cause was here: the mapper refused any artwork without a URI
/// scheme. A video's cover comes from the server as `https://…` and
/// passed; an audio clip's cover is the one the enricher extracts **from
/// the file itself** and writes to disk, so it arrives as a bare path and
/// was dropped — leaving the notification on the app icon. Hence "some".
PlaylistItem itemWithArt(String? art) => PlaylistItem(
  canonicalUrl: 'https://x/a',
  title: 'a',
  serverFilename: 'a.m4a',
  artworkUrl: art,
  isAudio: true,
);

void main() {
  group('the cover reaches the notification', () {
    test('an absolute path becomes a file: URI', () {
      final art = itemWithArt('/data/user/0/app/files/thumbs/a.jpg')
          .toMediaItem()
          .artUri;

      // Android decodes a file path happily; it only ever needed the
      // scheme in front of it.
      expect(art, isNotNull, reason: 'this is the audio cover that vanished');
      expect(art!.scheme, 'file');
      expect(
        art.toFilePath(windows: false),
        '/data/user/0/app/files/thumbs/a.jpg',
      );
    });

    test('a path with spaces survives, encoded', () {
      final art = itemWithArt('/sdcard/Download/My Clip.jpg')
          .toMediaItem()
          .artUri;

      expect(art!.toFilePath(windows: false), '/sdcard/Download/My Clip.jpg');
    });

    test('an http cover still passes through untouched', () {
      final art = itemWithArt('https://i.ytimg.com/vi/x/hq.jpg')
          .toMediaItem()
          .artUri;

      expect(art.toString(), 'https://i.ytimg.com/vi/x/hq.jpg');
    });

    test('nothing, empty and blank stay null', () {
      expect(itemWithArt(null).toMediaItem().artUri, isNull);
      expect(itemWithArt('').toMediaItem().artUri, isNull);
      expect(itemWithArt('   ').toMediaItem().artUri, isNull);
    });

    test('a relative path is still refused', () {
      // Not artwork but a bug upstream: accepting it would put a broken
      // reference on the lock screen instead of the app icon.
      expect(itemWithArt('thumbs/a.jpg').toMediaItem().artUri, isNull);
    });

    test('the round trip back from a MediaItem keeps the cover', () {
      final item = itemWithArt('/files/a.jpg');
      final back = playlistItemFromMediaItem(item.toMediaItem());

      expect(back?.artworkUrl, 'file:///files/a.jpg');
      expect(
        playlistItemFromMediaItem(back!.toMediaItem())?.artworkUrl,
        'file:///files/a.jpg',
        reason: 'a second trip must not mangle what the first produced',
      );
    });
  });
}
