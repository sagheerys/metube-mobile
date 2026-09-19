import 'package:mt_core/mt_core.dart';
import 'package:test/test.dart';

/// **§2.6, read from MeTube's own source 2026-09-19.** The endpoint exists
/// (`app/main.py`), the official image stamps the build date into
/// `METUBE_VERSION`, and the GitHub release tags are the same dated shape —
/// so "is there a newer one" is a string comparison and nothing more.
///
/// The care here is all about **refusing to answer** rather than answering:
/// a hand-built image says `dev`, an older MeTube 404s, and a proxy may
/// return an HTML page. Each of those must come out as "unknown", because
/// the alternative is telling someone their server is out of date when it
/// is not.
void main() {
  group('reading what the server says', () {
    test('a normal answer', () {
      final v = ServerVersion.fromJson({
        'version': '2026.09.15',
        'yt-dlp': '2026.09.10',
      });

      expect(v!.version, '2026.09.15');
      expect(v.ytDlp, '2026.09.10');
      expect(v.isKnown, isTrue);
    });

    test('`dev` is read, and is not a version', () {
      final v = ServerVersion.fromJson({'version': 'dev'});

      expect(v!.version, 'dev');
      expect(v.isKnown, isFalse, reason: 'an image built by hand');
    });

    test('whitespace is trimmed and an empty version is refused', () {
      expect(
        ServerVersion.fromJson({'version': '  2026.09.15 '})!.version,
        '2026.09.15',
      );
      expect(ServerVersion.fromJson({'version': '   '}), isNull);
      expect(ServerVersion.fromJson({'version': ''}), isNull);
    });

    test('anything that is not a JSON object with a version is refused', () {
      // A proxy's HTML page, a list, a bare string: none of them is a
      // version, and inventing one would put a lie on the screen.
      expect(ServerVersion.fromJson('<html>...'), isNull);
      expect(ServerVersion.fromJson(const []), isNull);
      expect(ServerVersion.fromJson(const {'yt-dlp': '2026.09.10'}), isNull);
      expect(ServerVersion.fromJson(const {'version': 42}), isNull);
      expect(ServerVersion.fromJson(null), isNull);
    });

    test('a missing yt-dlp is null rather than empty', () {
      expect(
        ServerVersion.fromJson(const {'version': '2026.09.15'})!.ytDlp,
        isNull,
      );
      expect(
        ServerVersion.fromJson(const {'version': '2026.09.15', 'yt-dlp': '  '})!
            .ytDlp,
        isNull,
      );
    });
  });

  group('is there a newer one', () {
    ServerVersion of(String v) => ServerVersion(version: v);

    test('a later date is newer', () {
      expect(of('2026.08.28').isOlderThan('2026.09.15'), isTrue);
      expect(of('2026.09.15').isOlderThan('2026.09.15'), isFalse);
      expect(of('2026.09.15').isOlderThan('2026.08.28'), isFalse);
    });

    test('the comparison is by date, not by string length', () {
      // The trap a naive parser falls into: 2026.10.01 sorts after
      // 2026.09.15 lexically **and** chronologically, which is why the
      // fixed-width dated form is required on both sides.
      expect(of('2026.09.15').isOlderThan('2026.10.01'), isTrue);
      expect(of('2026.10.01').isOlderThan('2026.09.15'), isFalse);
      expect(of('2025.12.31').isOlderThan('2026.01.01'), isTrue);
    });

    test('`dev` is never out of date', () {
      expect(of('dev').isOlderThan('2026.09.15'), isFalse);
    });

    test('a shape we do not understand answers "no", never "yes"', () {
      // A fork numbering its releases differently gets silence, not a
      // wrong update notice.
      expect(of('v1.2.3').isOlderThan('2026.09.15'), isFalse);
      expect(of('2026.09.15').isOlderThan('v1.2.3'), isFalse);
      expect(of('2026.9.15').isOlderThan('2026.09.15'), isFalse);
      expect(of('').isOlderThan('2026.09.15'), isFalse);
    });
  });
}
