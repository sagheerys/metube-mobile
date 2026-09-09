import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';
import 'package:mt_media/mt_media.dart';

final _endpoint = ServerStreamEndpoint(
  buildUrl: (name) {
    if (!UrlKit.isSafeServerFilename(name)) {
      throw const UnsafeFilenameException();
    }
    return 'https://srv/download/${Uri.encodeComponent(name)}';
  },
  headers: const {'Authorization': 'Basic dGVzdA=='},
);

PlaylistItem _item({String? localPath, String? filename}) => PlaylistItem(
  canonicalUrl: 'https://youtube.com/watch?v=abc',
  title: 'مقطع',
  localPath: localPath,
  serverFilename: filename,
);

void main() {
  group('the golden rule', () {
    test('a local file that exists beats the stream', () {
      final resolver = PlaybackSourceResolver(
        endpoint: _endpoint,
        fileExists: (_) => true,
      );
      final source = resolver.resolve(
        _item(localPath: '/sd/v.mp4', filename: 'v.mp4'),
      )!;
      expect(source.origin, PlaybackOrigin.local);
      expect(source.isLocal, isTrue);
      expect(source.headers, isEmpty);
    });

    test('a recorded path whose file was deleted falls back to streaming', () {
      final resolver = PlaybackSourceResolver(
        endpoint: _endpoint,
        fileExists: (_) => false,
      );
      final source = resolver.resolve(
        _item(localPath: '/sd/gone.mp4', filename: 'v.mp4'),
      )!;
      expect(source.origin, PlaybackOrigin.stream);
      expect(source.uri.toString(), 'https://srv/download/v.mp4');
    });

    test('the stream carries the authentication header', () {
      final resolver = PlaybackSourceResolver(
        endpoint: _endpoint,
        fileExists: (_) => false,
      );
      final source = resolver.resolve(_item(filename: 'v.mp4'))!;
      expect(source.headers['Authorization'], 'Basic dGVzdA==');
    });

    test('the filename is encoded into the URL, spaces and Arabic alike', () {
      final resolver = PlaybackSourceResolver(
        endpoint: _endpoint,
        fileExists: (_) => false,
      );
      final source = resolver.resolve(_item(filename: 'مقطع جديد.mp4'))!;
      expect(source.uri.toString(), contains('%20'));
      expect(source.uri.toString(), isNot(contains(' ')));
    });
  });

  group('no source', () {
    test('no local file and no name on the server', () {
      final resolver = PlaybackSourceResolver(
        endpoint: _endpoint,
        fileExists: (_) => false,
      );
      expect(resolver.resolve(_item()), isNull);
    });

    test('a malicious `../` filename is never streamed', () {
      final resolver = PlaybackSourceResolver(
        endpoint: _endpoint,
        fileExists: (_) => false,
      );
      expect(resolver.resolve(_item(filename: '../../etc/passwd')), isNull);
    });

    test('with no server configured, local only', () {
      final resolver = PlaybackSourceResolver(
        endpoint: ServerStreamEndpoint.none,
        fileExists: (_) => false,
      );
      expect(resolver.resolve(_item(filename: 'v.mp4')), isNull);
    });
  });

  group('PlaylistItem', () {
    test('identity is the canonicalUrl, not the title', () {
      const a = PlaylistItem(canonicalUrl: 'u', title: 'أ');
      const b = PlaylistItem(canonicalUrl: 'u', title: 'ب');
      expect(a, b);
      expect({a, b}.length, 1);
    });

    test(
      'a short is portrait and at most 3 minutes; unknown is not a short',
      () {
        const short = PlaylistItem(
          canonicalUrl: 'u',
          title: 't',
          duration: Duration(seconds: 40),
          aspectRatio: 0.5625,
        );
        const longVideo = PlaylistItem(
          canonicalUrl: 'u',
          title: 't',
          duration: Duration(minutes: 9),
          aspectRatio: 0.5625,
        );
        const wide = PlaylistItem(
          canonicalUrl: 'u',
          title: 't',
          duration: Duration(seconds: 40),
          aspectRatio: 1.77,
        );
        const unknown = PlaylistItem(canonicalUrl: 'u', title: 't');
        expect(short.isShortForm, isTrue);
        expect(longVideo.isShortForm, isFalse);
        expect(wide.isShortForm, isFalse);
        expect(unknown.isShortForm, isFalse);
      },
    );

    test('audio never enters the shorts lane, whatever its duration', () {
      const audio = PlaylistItem(
        canonicalUrl: 'u',
        title: 't',
        isAudio: true,
        duration: Duration(seconds: 30),
        aspectRatio: 0.5,
      );
      expect(audio.isShortForm, isFalse);
    });

    test('JSON there and back', () {
      const item = PlaylistItem(
        canonicalUrl: 'https://x/1',
        title: 'عنوان',
        uploader: 'قناة',
        localPath: '/sd/a.mp3',
        serverFilename: 'a.mp3',
        isAudio: true,
        duration: Duration(seconds: 90),
        aspectRatio: 1.5,
      );
      final back = PlaylistItem.fromJson(item.toJson())!;
      expect(back.canonicalUrl, item.canonicalUrl);
      expect(back.title, 'عنوان');
      expect(back.uploader, 'قناة');
      expect(back.localPath, '/sd/a.mp3');
      expect(back.isAudio, isTrue);
      expect(back.duration, const Duration(seconds: 90));
      expect(back.aspectRatio, 1.5);
    });

    test('an item with no URL is dropped', () {
      expect(PlaylistItem.fromJson({'title': 'بلا رابط'}), isNull);
    });
  });
}
