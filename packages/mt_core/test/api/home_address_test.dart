import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// A password typed with an `http://` address on the internet travels as
/// plain text; the setting screens warn about it, and must not cry wolf for
/// an address inside the house.
void main() {
  group('sendsPasswordInTheClear', () {
    test('an http address on the internet does', () {
      for (final url in [
        'http://my-nas.duckdns.org:8081',
        'http://metube.example.com',
        'HTTP://Metube.Example.com/',
        'http://8.8.8.8:8081',
        'http://172.32.0.1',
        'http://100.128.0.1',
        'http://[2001:db8::1]:8081',
      ]) {
        expect(HomeAddress.sendsPasswordInTheClear(url), isTrue, reason: url);
      }
    });

    test('an address on the home network or a VPN mesh does not', () {
      for (final url in [
        'http://192.168.1.20:8081',
        'http://10.0.2.2:8099',
        'http://172.16.5.4',
        'http://172.31.255.1',
        'http://127.0.0.1:8081',
        'http://localhost:8081',
        'http://nas:8081',
        'http://nas.local:8081',
        'http://nas.lan',
        'http://nas.home.arpa',
        'http://100.101.102.103:8081',
        'http://nas.tail1234.ts.net',
        'http://169.254.10.1',
        'http://[fd12:3456::1]:8081',
        'http://[fe80::1]',
        'http://[::1]:8081',
      ]) {
        expect(HomeAddress.sendsPasswordInTheClear(url), isFalse, reason: url);
      }
    });

    test('https never does, wherever it points', () {
      expect(
        HomeAddress.sendsPasswordInTheClear('https://my-nas.duckdns.org'),
        isFalse,
      );
    });

    test('what is not an address is left to the connection test', () {
      for (final url in ['', 'http://', 'my-nas.duckdns.org', 'ftp://x.com']) {
        expect(HomeAddress.sendsPasswordInTheClear(url), isFalse, reason: url);
      }
    });
  });
}
