import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// Cloudflare Access service-token headers.
///
/// The pair is a live credential, so what these tests pin is mostly what
/// must NOT happen: half a pair on the wire, the secret over cleartext HTTP,
/// the secret printed by an innocent string interpolation.
void main() {
  const id = '4c1f0d7a.access';
  const secret = '9a7e11c0b2d4f6a8';

  group('CloudflareAccess.headersFor', () {
    test('a complete pair on https builds exactly the two headers', () {
      final access = CloudflareAccess(clientId: id, clientSecret: secret);
      expect(access.headersFor('https://metube.example.com'), {
        'CF-Access-Client-Id': id,
        'CF-Access-Client-Secret': secret,
      });
    });

    test('a one-sided pair builds none: half a pair is never sent', () {
      expect(
        CloudflareAccess(
          clientId: id,
          clientSecret: '',
        ).headersFor('https://metube.example.com'),
        isEmpty,
      );
      expect(
        CloudflareAccess(
          clientId: '',
          clientSecret: secret,
        ).headersFor('https://metube.example.com'),
        isEmpty,
      );
    });

    test(
      'an http address gets nothing: the secret never crosses cleartext',
      () {
        final access = CloudflareAccess(clientId: id, clientSecret: secret);
        expect(access.headersFor('http://192.168.1.20:8081'), isEmpty);
        expect(access.headersFor('http://metube.example.com'), isEmpty);
      },
    );

    test('the scheme check is case-insensitive and tolerates a bare host', () {
      final access = CloudflareAccess(clientId: id, clientSecret: secret);
      expect(access.headersFor('HTTPS://metube.example.com'), isNotEmpty);
      // An address typed without a scheme is not https, so nothing is sent.
      expect(access.headersFor('metube.example.com'), isEmpty);
    });
  });

  group('CloudflareAccess values', () {
    test('surrounding whitespace and pasted line breaks are trimmed', () {
      final access = CloudflareAccess(
        clientId: '  $id\r\n',
        clientSecret: '\n\t$secret \n',
      );
      expect(access.clientId, id);
      expect(access.clientSecret, secret);
      expect(access.isComplete, isTrue);
    });

    test('a pair of blanks is empty, not complete', () {
      final access = CloudflareAccess(clientId: ' \n', clientSecret: '\t');
      expect(access.clientId, isEmpty);
      expect(access.isComplete, isFalse);
      expect(access.headersFor('https://metube.example.com'), isEmpty);
    });

    test('whitespace inside a value is kept: only the ends are trimmed', () {
      final access = CloudflareAccess(clientId: id, clientSecret: 'ab cd');
      expect(access.clientSecret, 'ab cd');
    });

    test('equality and hashCode cover both fields', () {
      final a = CloudflareAccess(clientId: id, clientSecret: secret);
      final same = CloudflareAccess(clientId: ' $id', clientSecret: secret);
      final otherSecret = CloudflareAccess(clientId: id, clientSecret: 'x');
      final otherId = CloudflareAccess(clientId: 'y', clientSecret: secret);
      expect(a, same);
      expect(a.hashCode, same.hashCode);
      expect(a, isNot(otherSecret));
      expect(a, isNot(otherId));
    });

    test('toString never contains either value', () {
      final access = CloudflareAccess(clientId: id, clientSecret: secret);
      expect('$access', isNot(contains(secret)));
      expect('$access', isNot(contains(id)));
      expect('$access', 'CloudflareAccess(***)');
    });
  });

  group('ServerConfig.access', () {
    test('no access yields no headers and the same config as before', () {
      final plain = ServerConfig(baseUrl: 'https://s.example.com');
      expect(plain.access, isNull);
      expect(plain.accessHeaders, isEmpty);
      // The shape every existing caller uses must still be equal to itself.
      expect(
        plain,
        ServerConfig(baseUrl: 'https://s.example.com/', access: null),
      );
    });

    test('accessHeaders follows the base URL scheme', () {
      final pair = CloudflareAccess(clientId: id, clientSecret: secret);
      expect(
        ServerConfig(
          baseUrl: 'https://s.example.com',
          access: pair,
        ).accessHeaders,
        hasLength(2),
      );
      expect(
        ServerConfig(
          baseUrl: 'http://s.example.com',
          access: pair,
        ).accessHeaders,
        isEmpty,
      );
    });

    test('equality and hashCode include access, so providers rebuild', () {
      final pair = CloudflareAccess(clientId: id, clientSecret: secret);
      final other = CloudflareAccess(clientId: id, clientSecret: 'changed');
      final base = ServerConfig(baseUrl: 'https://s.example.com');
      final withPair = ServerConfig(
        baseUrl: 'https://s.example.com',
        access: pair,
      );
      expect(withPair, isNot(base));
      expect(
        withPair,
        ServerConfig(baseUrl: 'https://s.example.com', access: pair),
      );
      expect(
        withPair.hashCode,
        ServerConfig(baseUrl: 'https://s.example.com', access: pair).hashCode,
      );
      expect(
        withPair,
        isNot(ServerConfig(baseUrl: 'https://s.example.com', access: other)),
      );
    });

    test('the Basic header is untouched by the pair', () {
      final pair = CloudflareAccess(clientId: id, clientSecret: secret);
      final withPair = ServerConfig(
        baseUrl: 'https://s.example.com',
        username: 'u',
        password: 'p',
        access: pair,
      );
      final without = ServerConfig(
        baseUrl: 'https://s.example.com',
        username: 'u',
        password: 'p',
      );
      expect(withPair.basicAuthHeader, without.basicAuthHeader);
    });
  });

  group('SecretKeys', () {
    test('the Cloudflare keys exist and are not the password keys', () {
      expect(SecretKeys.cfAccessClientId, 'cf_access_client_id');
      expect(SecretKeys.cfAccessClientSecret, 'cf_access_client_secret');
    });
  });

  group('typed fields, storage and the address switch', () {
    test('two empty fields are no Access; one filled is a half pair', () {
      expect(CloudflareAccess.typed('  ', '\n'), isNull);
      final half = CloudflareAccess.typed(id, '');
      expect(half, isNotNull);
      expect(half!.isComplete, isFalse);
      expect(CloudflareAccess.typed(' $id ', '$secret\n')!.isComplete, isTrue);
    });

    test('a saved pair loads back; a half pair never does', () async {
      final secrets = MemorySecretStore();
      final pair = CloudflareAccess(clientId: id, clientSecret: secret);
      await CloudflareAccess.save(secrets, pair);
      expect(await CloudflareAccess.load(secrets), pair);

      await secrets.delete(SecretKeys.cfAccessClientSecret);
      expect(await CloudflareAccess.load(secrets), isNull);
    });

    test('saving null or a half pair removes what was stored', () async {
      // Defect: clearing the fields left the old token in the store, so it
      // came back at the next start.
      final secrets = MemorySecretStore();
      await CloudflareAccess.save(
        secrets,
        CloudflareAccess(clientId: id, clientSecret: secret),
      );
      await CloudflareAccess.save(secrets, null);
      expect(await secrets.read(SecretKeys.cfAccessClientId), isNull);
      expect(await secrets.read(SecretKeys.cfAccessClientSecret), isNull);

      await secrets.write(SecretKeys.cfAccessClientId, id);
      await CloudflareAccess.save(secrets, CloudflareAccess.typed(id, ''));
      expect(await secrets.read(SecretKeys.cfAccessClientId), isNull);
    });

    test('another address keeps the whole account', () {
      // Defect: an address switch that rebuilt the config field by field
      // and dropped the pair, so the tunnel answered with a login page.
      final pair = CloudflareAccess(clientId: id, clientSecret: secret);
      final home = ServerConfig(
        baseUrl: 'http://192.168.1.10:8081',
        username: 'u',
        password: 'p',
        access: pair,
      );
      final away = home.at('https://metube.example.com/');
      expect(away.baseUrl, 'https://metube.example.com');
      expect(away.username, 'u');
      expect(away.password, 'p');
      expect(away.access, pair);
      // The home address is cleartext, so it still gets nothing.
      expect(home.accessHeaders, isEmpty);
      expect(away.accessHeaders, hasLength(2));
    });
  });
}
