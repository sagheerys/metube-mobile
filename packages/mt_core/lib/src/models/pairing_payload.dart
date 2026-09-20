import 'dart:convert';

import '../api/metube_api_client.dart' show ServerConfig;

/// **What a setup code carries** (م-74).
///
/// Super shows one; Lite reads it and configures itself. It exists because
/// the alternative is dictating `http://192.168.2.245:8086` down a hallway
/// to someone who has never typed a port number, and then a password after
/// it.
///
/// **It carries a password in the clear**, and nothing can change that:
/// the phone reading it has no prior secret to encrypt against. So the
/// code is a thing to show for a moment to someone standing next to you,
/// not a thing to send. The screen that draws it says so.
class PairingPayload {
  const PairingPayload({required this.url, this.username, this.password});

  /// The address the other phone will use. **One address, not the list**:
  /// Lite has a single server URL by design — the automatic switching
  /// between local and external is Super's alone.
  final String url;

  final String? username;
  final String? password;

  bool get hasCredentials =>
      (username?.isNotEmpty ?? false) || (password?.isNotEmpty ?? false);

  /// **A local address is useless away from the house.** The screen uses
  /// this to warn rather than to refuse: a family that never leaves the
  /// Wi-Fi is a real case, and so is one that does.
  bool get isPrivateAddress {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host == 'localhost' || host.endsWith('.local')) return true;
    final octets = host.split('.');
    if (octets.length != 4) return false;
    final first = int.tryParse(octets.first);
    final second = int.tryParse(octets[1]);
    if (first == null || second == null) return false;
    // The three private ranges, plus loopback and link-local.
    if (first == 10 || first == 127) return true;
    if (first == 192 && second == 168) return true;
    if (first == 169 && second == 254) return true;
    return first == 172 && second >= 16 && second <= 31;
  }

  /// **Short keys and a version**, because every character is a denser QR
  /// and a denser QR is a slower read in poor light.
  String encode() => jsonEncode({
    't': _tag,
    'v': _version,
    'u': url,
    if (username?.isNotEmpty ?? false) 'n': username,
    if (password?.isNotEmpty ?? false) 'p': password,
  });

  /// Returns null for anything that is not one of our codes.
  ///
  /// **The tag is checked before the shape**: a phone camera reads every
  /// QR it is pointed at, including a Wi-Fi code, a business card and a
  /// payment link, and telling someone "that is not a MeTube code" is the
  /// whole value of a tag.
  static PairingPayload? decode(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    if (decoded['t'] != _tag) return null;
    // An older app meeting a newer code should say so rather than guess at
    // fields it does not know.
    final version = decoded['v'];
    if (version is! int || version > _version) return null;
    final url = decoded['u'];
    if (url is! String) return null;
    final normalized = ServerConfig.normalizeBaseUrl(url);
    // **A scheme and a host, or nothing.** A code carrying `javascript:` or
    // a bare word must not reach the settings screen.
    final parsed = Uri.tryParse(normalized);
    if (parsed == null || !parsed.hasScheme || parsed.host.isEmpty) {
      return null;
    }
    if (parsed.scheme != 'http' && parsed.scheme != 'https') return null;
    return PairingPayload(
      url: normalized,
      username: _text(decoded['n']),
      password: _text(decoded['p']),
    );
  }

  static String? _text(Object? raw) {
    if (raw is! String) return null;
    return raw.isEmpty ? null : raw;
  }

  static const _tag = 'mtf-setup';
  static const _version = 1;

  /// The version this app writes, exposed for the documentation and the
  /// tests rather than guessed at.
  static int get version => _version;

  /// **The password is never in this string.** `toString` reaches logs,
  /// and the diagnostic log is a thing users are asked to share.
  @override
  String toString() =>
      'PairingPayload($url, user: ${username ?? '-'}, password: '
      '${(password?.isNotEmpty ?? false) ? 'set' : 'none'})';
}
