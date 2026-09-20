import 'package:flutter_test/flutter_test.dart';
import 'package:mt_core/mt_core.dart';

/// **What the scanner does with what the camera hands it** (م-74, Lite).
///
/// The camera itself is not exercised here: `mobile_scanner` needs a real
/// one, and a test that mocks a platform channel proves the mock works.
/// What *can* be proved is the decision the screen makes for every string
/// a camera might produce — which is where the risk actually is, because
/// a camera reads whatever it is pointed at.
///
/// The screen's own behaviour around these (one code acted on, the
/// connection tested before saving, the scanner restarted on failure) is
/// held by `ScanScreen` and checked by hand on the emulator.
void main() {
  /// Exactly the call `_onDetect` makes.
  PairingPayload? seen(String rawValue) => PairingPayload.decode(rawValue);

  test('the owner\'s code configures the phone', () {
    const code = PairingPayload(
      url: 'http://192.168.2.245:8086',
      username: 'family',
      password: 'secret',
    );
    final read = seen(code.encode())!;
    expect(read.url, 'http://192.168.2.245:8086');
    expect(read.username, 'family');
    expect(read.password, 'secret');
  });

  test('every other code a camera can land on is refused, so the scanner can '
      'say "that is not a MeTube code" instead of going quiet', () {
    for (final raw in [
      // The codes actually found on things people point phones at.
      'WIFI:S:HomeNet;T:WPA;P:hunter2;;',
      'BEGIN:VCARD\nVERSION:3.0\nFN:Someone\nEND:VCARD',
      'https://example.com/promo',
      'upi://pay?pa=someone@bank',
      'otpauth://totp/Example:me?secret=ABC',
      '00020101021126',
      'مرحبا',
    ]) {
      expect(seen(raw), isNull, reason: raw);
    }
  });

  test('a code that is ours but points somewhere dangerous is refused too: '
      'the scanner hands its result straight to the server setting', () {
    for (final url in ['javascript:alert(1)', 'file:///data', 'ftp://s']) {
      final raw = '{"t":"mtf-setup","v":1,"u":"$url"}';
      expect(seen(raw), isNull, reason: url);
    }
  });

  test('a partial read is not half-applied', () {
    // A QR caught mid-frame yields truncated text more often than it
    // yields nothing.
    const full =
        '{"t":"mtf-setup","v":1,"u":"https://s.example.com","p":"secret"}';
    for (var cut = 1; cut < full.length; cut++) {
      expect(seen(full.substring(0, cut)), isNull, reason: 'cut at $cut');
    }
    expect(seen(full), isNotNull);
  });
}
