import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

void main() {
  group('ShortLinkResolver', () {
    test('يتتبع سلسلة redirect حتى الوجهة', () async {
      final hops = {
        'https://vt.tiktok.com/ZS8abc/':
            'https://vm.tiktok.com/ZS8abc/redir',
        'https://vm.tiktok.com/ZS8abc/redir':
            'https://www.tiktok.com/@user/video/7301234567890123456',
      };
      final resolver = ShortLinkResolver(redirectStep: (url) async => hops[url]);
      expect(await resolver.resolve('https://vt.tiktok.com/ZS8abc/'),
          'https://www.tiktok.com/@user/video/7301234567890123456');
    });

    test('Location نسبي يُحل على الرابط الحالي', () async {
      final resolver = ShortLinkResolver(redirectStep: (url) async =>
          url == 'https://fb.watch/abc/' ? '/watch/?v=9876543210987' : null);
      expect(await resolver.resolve('https://fb.watch/abc/'),
          'https://fb.watch/watch/?v=9876543210987');
    });

    test('منع الهبوط HTTPS→HTTP ⇒ يعيد الأصلي', () async {
      final resolver = ShortLinkResolver(redirectStep: (url) async =>
          url == 'https://on.soundcloud.com/x' ? 'http://evil.com/t' : null);
      expect(await resolver.resolve('https://on.soundcloud.com/x'),
          'https://on.soundcloud.com/x');
    });

    test('غير القصير يمر دون أي طلب', () async {
      var calls = 0;
      final resolver = ShortLinkResolver(redirectStep: (url) async {
        calls++;
        return null;
      });
      const full = 'https://www.tiktok.com/@user/video/1';
      expect(await resolver.resolve(full), full);
      expect(calls, 0);
    });

    test('فشل الجلب ⇒ يعيد الأصلي كما هو', () async {
      final resolver = ShortLinkResolver(
          redirectStep: (url) async => throw Exception('network down'));
      expect(await resolver.resolve('https://vm.tiktok.com/x/'),
          'https://vm.tiktok.com/x/');
    });

    test('حلقة redirect لا نهائية تتوقف عند حد القفزات', () async {
      var calls = 0;
      final resolver = ShortLinkResolver(redirectStep: (url) async {
        calls++;
        return 'https://vm.tiktok.com/loop/';
      });
      await resolver.resolve('https://vm.tiktok.com/loop/');
      expect(calls, MTConstants.maxRedirectHops);
    });
  });
}
