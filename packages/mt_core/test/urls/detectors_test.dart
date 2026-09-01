import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  group('MediaPlatform.detect — القائمة الواحدة (م-4)', () {
    const cases = {
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ': MediaPlatform.youtube,
      'https://youtu.be/dQw4w9WgXcQ': MediaPlatform.youtube,
      'https://vm.tiktok.com/ZS8abc/': MediaPlatform.tiktok,
      'https://www.instagram.com/reel/Cxyz/': MediaPlatform.instagram,
      'https://on.soundcloud.com/AbCd': MediaPlatform.soundcloud,
      'https://x.com/user/status/1234567890123': MediaPlatform.x,
      'https://twitter.com/user/status/1': MediaPlatform.x,
      'https://fb.watch/abc/': MediaPlatform.facebook,
      'https://www.facebook.com/reel/123': MediaPlatform.facebook,
      'https://vimeo.com/76979871': MediaPlatform.vimeo,
      'https://www.twitch.tv/user/clip/SomeClip': MediaPlatform.twitch,
      'https://www.reddit.com/r/videos/comments/abc/': MediaPlatform.reddit,
      'https://www.dailymotion.com/video/x8abc': MediaPlatform.dailymotion,
      'https://example.com/video.mp4': MediaPlatform.other,
      '': MediaPlatform.other,
    };

    cases.forEach((url, platform) {
      test('"$url" ⇒ ${platform.name}', () {
        expect(MediaPlatform.detect(url), platform);
      });
    });

    test('isKnown يغذي الزر الذكي (م-2)', () {
      expect(MediaPlatform.isKnown('https://youtu.be/dQw4w9WgXcQ'), isTrue);
      expect(MediaPlatform.isKnown('https://example.com/x'), isFalse);
    });

    test('isYouTube', () {
      expect(MediaPlatform.youtube.isYouTube, isTrue);
      expect(MediaPlatform.tiktok.isYouTube, isFalse);
    });
  });

  group('PlaylistDetector — التوجيه التلقائي (م-5)', () {
    test('يوتيوب list= ⇒ youtube', () {
      expect(
          PlaylistDetector.detect(
              'https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLabc'),
          PlaylistKind.youtube);
    });

    test('يوتيوب /playlist ⇒ youtube', () {
      expect(PlaylistDetector.detect('https://www.youtube.com/playlist?list=PLx'),
          PlaylistKind.youtube);
    });

    test('SoundCloud /sets/ ⇒ soundcloud', () {
      expect(PlaylistDetector.detect('https://soundcloud.com/artist/sets/mylist'),
          PlaylistKind.soundcloud);
    });

    test('فيديو مفرد ⇒ none', () {
      expect(PlaylistDetector.detect('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
          PlaylistKind.none);
      expect(PlaylistDetector.detect('https://soundcloud.com/artist/track'),
          PlaylistKind.none);
      expect(PlaylistDetector.isPlaylist('https://youtu.be/dQw4w9WgXcQ'),
          isFalse);
    });

    test('list فارغ ⇒ none', () {
      expect(PlaylistDetector.detect('https://www.youtube.com/watch?v=x&list='),
          PlaylistKind.none);
    });
  });
}
