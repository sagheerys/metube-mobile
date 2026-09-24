import 'dart:convert';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// Lines as a browser exporter writes them: tab-separated, seven fields.
String row(String domain, String name, String value, {String path = '/'}) =>
    [domain, 'TRUE', path, 'TRUE', '1790000000', name, value].join('\t');

List<int> file(List<String> lines) => utf8.encode(
  '# Netscape HTTP Cookie File\n# comment\n\n${lines.join('\n')}\n',
);

List<String> cookiesIn(List<int>? merged) => const LineSplitter()
    .convert(utf8.decode(merged!))
    .where((l) => !l.startsWith('# '))
    .toList();

void main() {
  group('CookieFiles.merge — one file for a server that keeps only one', () {
    test('two platforms picked together both survive: the reason this '
        'exists, because MeTube replaces its cookies file whole', () {
      final merged = CookieFiles.merge([
        file([row('.youtube.com', 'SID', 'y1')]),
        file([row('.vimeo.com', 'vuid', 'v1')]),
      ]);

      expect(cookiesIn(merged), [
        row('.youtube.com', 'SID', 'y1'),
        row('.vimeo.com', 'vuid', 'v1'),
      ]);
      expect(utf8.decode(merged!), startsWith(CookieFiles.header));
    });

    test('#HttpOnly_ lines are cookies, not comments — dropping them would '
        'drop most sign-in cookies', () {
      final merged = CookieFiles.merge([
        file([row('#HttpOnly_.youtube.com', '__Secure-3PSID', 's')]),
      ]);

      expect(cookiesIn(merged), [
        row('#HttpOnly_.youtube.com', '__Secure-3PSID', 's'),
      ]);
    });

    test('the same cookie in two files is kept once, from the LATER file', () {
      final merged = CookieFiles.merge([
        file([row('.vimeo.com', 'vuid', 'old'), row('.vimeo.com', 'a', '1')]),
        file([row('.Vimeo.com', 'vuid', 'new')]),
      ]);

      expect(cookiesIn(merged), [
        row('.vimeo.com', 'a', '1'),
        row('.Vimeo.com', 'vuid', 'new'),
      ]);
    });

    test('the same name on another path is another cookie', () {
      final merged = CookieFiles.merge([
        file([
          row('.x.com', 'id', '1'),
          row('.x.com', 'id', '2', path: '/api'),
        ]),
      ]);

      expect(cookiesIn(merged), hasLength(2));
    });

    test('Windows line endings are read, and not carried into a value', () {
      final merged = CookieFiles.merge([
        utf8.encode(
          '${row('.x.com', 'a', '1')}\r\n${row('.x.com', 'b', '2')}\r\n',
        ),
      ]);

      expect(cookiesIn(merged), [
        row('.x.com', 'a', '1'),
        row('.x.com', 'b', '2'),
      ]);
    });

    test('a file with not one cookie in it — a JSON export — is refused, '
        'not sent to replace a working file', () {
      expect(CookieFiles.merge([utf8.encode('[{"name":"SID"}]')]), isNull);
      expect(CookieFiles.merge([file(const [])]), isNull);
    });

    test('the sites are named for the person reading: subdomains fold into '
        'their site, HttpOnly counts, a country second level keeps three '
        'labels, and the list is sorted and unique', () {
      final merged = CookieFiles.merge([
        file([
          row('.youtube.com', 'SID', '1'),
          row('#HttpOnly_accounts.google.com', 'LSID', '2'),
          row('.google.com', 'NID', '3'),
          row('www.bbc.co.uk', 'ckns', '4'),
          row('vimeo.com', 'vuid', '5'),
        ]),
      ])!;

      expect(CookieFiles.sites(merged), [
        'bbc.co.uk',
        'google.com',
        'vimeo.com',
        'youtube.com',
      ]);
    });

    test('a file with no cookie lines names no site', () {
      expect(CookieFiles.sites(utf8.encode('[{"name":"SID"}]')), isEmpty);
    });

    test('a bad line among good ones is skipped, not fatal', () {
      final merged = CookieFiles.merge([
        file(['not a cookie line', row('.x.com', 'a', '1')]),
      ]);

      expect(cookiesIn(merged), [row('.x.com', 'a', '1')]);
    });
  });
}
