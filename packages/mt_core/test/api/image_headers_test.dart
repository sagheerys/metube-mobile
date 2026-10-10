import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// **The server's password stays with the server (2026-10-10)**: covers
/// were requested with it whatever their address, so a locked server's
/// credentials went to YouTube's and other platforms' image hosts.
void main() {
  final locked = MeTubeApiClient(
    config: ServerConfig(
      baseUrl: 'https://mtube.example.com/',
      username: 'owner',
      password: 'secret',
    ),
  );

  test('a YouTube thumbnail gets no password', () {
    expect(
      locked.imageHeadersFor(
        'https://i.ytimg.com/vi/MfDROnE8FG8/hqdefault.jpg',
      ),
      isEmpty,
    );
  });

  test('another platform\'s cover gets none either', () {
    expect(
      locked.imageHeadersFor('https://scontent.cdninstagram.com/v/a.jpg'),
      isEmpty,
    );
  });

  test('an image on the server itself keeps it', () {
    expect(
      locked.imageHeadersFor('https://mtube.example.com/download/a.jpg'),
      containsPair('Authorization', isNotEmpty),
    );
  });

  test('a host that only starts like the server is another host', () {
    expect(sameOrigin('http://nas:80861/a.jpg', 'http://nas:8086'), isFalse);
    expect(sameOrigin('http://nas.evil.com/a', 'http://nas'), isFalse);
    expect(sameOrigin('https://nas/a', 'http://nas'), isFalse);
    expect(sameOrigin('http://NAS:8086/a', 'http://nas:8086'), isTrue);
    expect(sameOrigin('/storage/a.jpg', 'http://nas:8086'), isFalse);
  });
}
