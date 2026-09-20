import 'dart:convert';

import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// **The setup code** (م-74): what Super draws and Lite reads.
///
/// A camera reads whatever it is pointed at, so most of this file is about
/// refusing things: another app's QR, a code from a newer version, and a
/// URL that is not a server address at all.
void main() {
  const payload = PairingPayload(
    url: 'https://mtube.example.com',
    username: 'family',
    password: 'p@ss word',
  );

  group('round trip', () {
    test('what is written is what is read', () {
      final read = PairingPayload.decode(payload.encode())!;
      expect(read.url, payload.url);
      expect(read.username, payload.username);
      expect(read.password, payload.password);
    });

    test('a server with no password carries none', () {
      const open = PairingPayload(url: 'http://192.168.1.9:8081');
      final read = PairingPayload.decode(open.encode())!;
      expect(read.username, isNull);
      expect(read.password, isNull);
      expect(read.hasCredentials, isFalse);
      // And the keys are absent rather than empty, which is smaller.
      final map = jsonDecode(open.encode()) as Map;
      expect(map.containsKey('n'), isFalse);
      expect(map.containsKey('p'), isFalse);
    });

    test('a trailing slash is normalised away, as everywhere else', () {
      const messy = PairingPayload(url: '  https://s.example.com//  ');
      expect(
        PairingPayload.decode(messy.encode())!.url,
        'https://s.example.com',
      );
    });

    test('the code is versioned and tagged', () {
      final map = jsonDecode(payload.encode()) as Map;
      expect(map['t'], 'mtf-setup');
      expect(map['v'], PairingPayload.version);
    });
  });

  group('refusing what is not ours', () {
    test('another app\'s QR is not a setup code', () {
      // A Wi-Fi code, a URL, a phone number, plain words.
      for (final raw in [
        'WIFI:S:Home;T:WPA;P:secret;;',
        'https://example.com',
        'tel:+9665000000',
        'hello',
        '',
        '   ',
        '{}',
        '[]',
      ]) {
        expect(PairingPayload.decode(raw), isNull, reason: raw);
      }
    });

    test('valid JSON without our tag is refused', () {
      expect(PairingPayload.decode('{"v":1,"u":"https://s.com"}'), isNull);
      expect(
        PairingPayload.decode('{"t":"other","v":1,"u":"https://s.com"}'),
        isNull,
      );
    });

    test('a code from a NEWER app is refused rather than half-read: guessing '
        'at fields we do not know is how a wrong server gets saved', () {
      final future = jsonEncode({
        't': 'mtf-setup',
        'v': PairingPayload.version + 1,
        'u': 'https://s.com',
      });
      expect(PairingPayload.decode(future), isNull);
    });

    test('an older version is still readable', () {
      // v1 is what exists today; the guard is that the check is "newer
      // than us", not "different from us".
      final old = jsonEncode({'t': 'mtf-setup', 'v': 1, 'u': 'https://s.com'});
      expect(PairingPayload.decode(old)?.url, 'https://s.com');
    });

    test('only http and https: a code carrying javascript: or file: must '
        'never reach the settings screen', () {
      for (final url in [
        'javascript:alert(1)',
        'file:///etc/passwd',
        'ftp://s.com',
        'not a url',
        '',
        '/relative/path',
      ]) {
        final raw = jsonEncode({'t': 'mtf-setup', 'v': 1, 'u': url});
        expect(PairingPayload.decode(raw), isNull, reason: url);
      }
    });

    test('a missing or non-string url is refused', () {
      expect(PairingPayload.decode('{"t":"mtf-setup","v":1}'), isNull);
      expect(PairingPayload.decode('{"t":"mtf-setup","v":1,"u":42}'), isNull);
    });
  });

  group('telling a house address from a public one', () {
    test('the private ranges, loopback and link-local are private', () {
      for (final host in [
        '192.168.2.245:8086',
        '10.0.0.5',
        '172.16.4.4',
        '172.31.255.255',
        '127.0.0.1',
        '169.254.1.1',
        'localhost:8081',
        'nas.local',
      ]) {
        expect(
          PairingPayload(url: 'http://$host').isPrivateAddress,
          isTrue,
          reason: host,
        );
      }
    });

    test('a real hostname and the ranges just outside are not', () {
      for (final host in [
        'mtube.example.com',
        '172.15.0.1',
        '172.32.0.1',
        '11.0.0.1',
        '193.168.1.1',
        '8.8.8.8',
      ]) {
        expect(
          PairingPayload(url: 'https://$host').isPrivateAddress,
          isFalse,
          reason: host,
        );
      }
    });
  });

  test('toString never carries the password: it reaches the diagnostic log, '
      'and the log is a thing users are asked to share', () {
    final text = payload.toString();
    expect(text, isNot(contains('p@ss word')));
    expect(text, contains('family'));
    expect(text, contains('set'));
    expect(
      const PairingPayload(url: 'https://s.com').toString(),
      contains('none'),
    );
  });
}
