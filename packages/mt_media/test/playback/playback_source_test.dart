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
  group('القاعدة الذهبية (م-19)', () {
    test('الملف المحلي الموجود يفوز على البث', () {
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

    test('مسار مسجَّل لكن الملف محذوف من القرص ⇒ يسقط للبث', () {
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

    test('البث يحمل ترويسة المصادقة', () {
      final resolver = PlaybackSourceResolver(
        endpoint: _endpoint,
        fileExists: (_) => false,
      );
      final source = resolver.resolve(_item(filename: 'v.mp4'))!;
      expect(source.headers['Authorization'], 'Basic dGVzdA==');
    });

    test('اسم الملف يُرمَّز في الرابط (مسافات وعربية)', () {
      final resolver = PlaybackSourceResolver(
        endpoint: _endpoint,
        fileExists: (_) => false,
      );
      final source = resolver.resolve(_item(filename: 'مقطع جديد.mp4'))!;
      expect(source.uri.toString(), contains('%20'));
      expect(source.uri.toString(), isNot(contains(' ')));
    });
  });

  group('لا مصدر', () {
    test('بلا ملف محلي ولا اسم على السيرفر', () {
      final resolver = PlaybackSourceResolver(
        endpoint: _endpoint,
        fileExists: (_) => false,
      );
      expect(resolver.resolve(_item()), isNull);
    });

    test('اسم ملف خبيث `../` لا يُبث أبداً (القاعدة 9)', () {
      final resolver = PlaybackSourceResolver(
        endpoint: _endpoint,
        fileExists: (_) => false,
      );
      expect(resolver.resolve(_item(filename: '../../etc/passwd')), isNull);
    });

    test('بلا سيرفر مُعد: المحلي فقط', () {
      final resolver = PlaybackSourceResolver(
        endpoint: ServerStreamEndpoint.none,
        fileExists: (_) => false,
      );
      expect(resolver.resolve(_item(filename: 'v.mp4')), isNull);
    });
  });

  group('PlaylistItem', () {
    test('الهوية بالـ canonicalUrl لا بالعنوان', () {
      const a = PlaylistItem(canonicalUrl: 'u', title: 'أ');
      const b = PlaylistItem(canonicalUrl: 'u', title: 'ب');
      expect(a, b);
      expect({a, b}.length, 1);
    });

    test('القصير = عمودي و≤3 دقائق؛ المجهول ليس قصيراً (م-35)', () {
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
    });

    test('الصوت لا يدخل مسار القِصار مهما كانت مدته', () {
      const audio = PlaylistItem(
        canonicalUrl: 'u',
        title: 't',
        isAudio: true,
        duration: Duration(seconds: 30),
        aspectRatio: 0.5,
      );
      expect(audio.isShortForm, isFalse);
    });

    test('JSON ذهاباً وإياباً', () {
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

    test('عنصر بلا رابط يُهمل', () {
      expect(PlaylistItem.fromJson({'title': 'بلا رابط'}), isNull);
    });
  });
}
