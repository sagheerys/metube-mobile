import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// An address typed as `https://user:pass@host` (security review
/// 2026-11-05): it worked, because the HTTP client sends the pair by itself,
/// but the password then lived in plain settings, in the settings summary
/// and in backups.
void main() {
  group('ServerConfig', () {
    test('**the guard**: the pair moves from the address to the fields', () {
      final config = ServerConfig(baseUrl: 'https://me:s%40cret@nas.example/');
      expect(config.baseUrl, 'https://nas.example');
      expect(config.username, 'me');
      expect(config.password, 's@cret');
      expect(config.basicAuthHeader, isNotNull);
    });

    test('what was typed in the fields wins over the address', () {
      final config = ServerConfig(
        baseUrl: 'https://old:old@nas.example',
        username: 'new',
        password: 'newpass',
      );
      expect(config.baseUrl, 'https://nas.example');
      expect(config.username, 'new');
      expect(config.password, 'newpass');
    });

    test('a user with no password, and an address with none at all', () {
      final user = ServerConfig(baseUrl: 'http://me@192.168.1.20:8081');
      expect(user.baseUrl, 'http://192.168.1.20:8081');
      expect(user.username, 'me');
      expect(user.password, isNull);

      final plain = ServerConfig(baseUrl: 'http://192.168.1.20:8081/');
      expect(plain.baseUrl, 'http://192.168.1.20:8081');
      expect(plain.hasCredentials, isFalse);
    });
  });

  group('ServerConfig.hostLabel', () {
    test('shows host and port, never the pair', () {
      expect(
        ServerConfig.hostLabel('https://me:secret@nas.example:8443/x'),
        'nas.example:8443',
      );
      expect(
        ServerConfig.hostLabel('http://192.168.1.20:8081'),
        '192.168.1.20:8081',
      );
      expect(
        ServerConfig.hostLabel('https://metube.example.com'),
        'metube.example.com',
      );
      expect(ServerConfig.hostLabel('not an address'), 'not an address');
    });
  });
}
