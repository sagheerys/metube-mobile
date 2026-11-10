/// Where a server address sits: on the home network, or out on the internet.
///
/// The apps send the server password with every request as HTTP Basic
/// authentication. Over `https://` that is encrypted; over `http://` it is
/// plain text, which is fine inside the house and is not across the
/// internet, where anyone on the path can read it. Nothing told the person
/// typing `http://my-nas.duckdns.org:8081` that, so the setting screens use
/// [HomeAddress.sendsPasswordInTheClear] to say it beside the field.
abstract final class HomeAddress {
  /// True when [host] is on a network the user's own router keeps: the
  /// private IPv4 ranges, loopback, the carrier-grade range that VPN meshes
  /// such as Tailscale hand out (their traffic is encrypted by the mesh),
  /// IPv6 unique-local and link-local addresses, a single-label name, and
  /// the names reserved for home networks.
  static bool isHome(String host) {
    final h = host.toLowerCase().replaceAll(RegExp(r'^\[|\]$'), '');
    if (h.isEmpty) return false;
    if (h == 'localhost' || h == '::1') return true;
    if (h.contains(':')) {
      // IPv6: fc00::/7 unique-local and fe80::/10 link-local.
      return RegExp(r'^f[cd][0-9a-f]{0,2}:').hasMatch(h) ||
          RegExp(r'^fe[89ab][0-9a-f]?:').hasMatch(h);
    }
    for (final suffix in _homeSuffixes) {
      if (h.endsWith(suffix)) return true;
    }
    final octets = h.split('.');
    if (octets.length != 4) return !h.contains('.');
    final n = octets.map(int.tryParse).toList();
    // A dotted name that is not four numbers is a domain on the internet.
    if (n.any((v) => v == null || v < 0 || v > 255)) return false;
    final a = n[0]!, b = n[1]!;
    return a == 10 ||
        a == 127 ||
        (a == 192 && b == 168) ||
        (a == 172 && b >= 16 && b <= 31) ||
        (a == 169 && b == 254) ||
        (a == 100 && b >= 64 && b <= 127);
  }

  /// True when saving [url] with a password would send that password as
  /// plain text across the internet: an `http://` address whose host is
  /// not [isHome]. An address that does not parse is not judged here; the
  /// connection test reports it.
  static bool sendsPasswordInTheClear(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.scheme.toLowerCase() != 'http') return false;
    return uri.host.isNotEmpty && !isHome(uri.host);
  }

  static const _homeSuffixes = [
    '.local',
    '.lan',
    '.home',
    '.home.arpa',
    '.internal',
    '.localdomain',
    '.ts.net',
  ];
}
