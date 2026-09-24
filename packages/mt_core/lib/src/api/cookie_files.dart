import 'dart:convert';

/// **Several cookies files, sent as the one the server keeps.**
///
/// MeTube holds a single `cookies.txt` and every upload replaces it whole
/// (`os.replace` in `upload-cookies`). So sending Vimeo's file after
/// YouTube's signs YouTube out, and the only way to keep both is one file
/// that carries both. This builds it in memory from files the user picked
/// together; nothing is written to the phone.
///
/// The format is Netscape's: one cookie per line, seven tab-separated
/// fields, `#` for comments — **except `#HttpOnly_`**, which is a cookie
/// whose domain is marked HTTP-only, and which browsers' exporters write
/// for most sign-in cookies. Reading it as a comment would drop exactly
/// the cookies that matter.
abstract final class CookieFiles {
  static const header = '# Netscape HTTP Cookie File';
  static const _httpOnly = '#HttpOnly_';

  /// The merged file, or null when not one line of any file is a cookie:
  /// a JSON export or a random text file should be refused here, not sent
  /// to replace a working file on the server.
  ///
  /// The same cookie (domain, path, name) in two files is kept once, **from
  /// the later file**, so re-picking a fresh export with an old one does
  /// not revive the old value.
  static List<int>? merge(List<List<int>> files) {
    final byKey = <String, String>{};
    for (final bytes in files) {
      final text = utf8.decode(bytes, allowMalformed: true);
      for (final raw in const LineSplitter().convert(text)) {
        final line = raw.trim();
        if (line.isEmpty) continue;
        if (line.startsWith('#') && !line.startsWith(_httpOnly)) continue;
        final fields = raw.trimLeft().split('\t');
        if (fields.length < 7) continue;
        final domain = fields[0].startsWith(_httpOnly)
            ? fields[0].substring(_httpOnly.length)
            : fields[0];
        final key = '${domain.toLowerCase()}\t${fields[2]}\t${fields[5]}';
        // Removed first so the later file's line also takes the later place.
        byKey
          ..remove(key)
          ..[key] = raw.trimLeft();
      }
    }
    if (byKey.isEmpty) return null;
    return utf8.encode('$header\n${byKey.values.join('\n')}\n');
  }

  /// **The sites a file carries cookies for**, so the screen can say what
  /// was sent: after picking two files, "Cookies sent for: vimeo.com ·
  /// youtube.com" is the only proof that both went in. Read at the moment
  /// of sending and kept nowhere.
  ///
  /// A cookie for `accounts.google.com` and one for `.google.com` are the
  /// same site to the person reading, so each host is cut to its last two
  /// labels — three when the last two look like a country's second level
  /// (`bbc.co.uk`, not `co.uk`).
  static List<String> sites(List<int> bytes) {
    final found = <String>{};
    final text = utf8.decode(bytes, allowMalformed: true);
    for (final raw in const LineSplitter().convert(text)) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      if (line.startsWith('#') && !line.startsWith(_httpOnly)) continue;
      final fields = line.split('\t');
      if (fields.length < 7) continue;
      var host = fields[0];
      if (host.startsWith(_httpOnly)) host = host.substring(_httpOnly.length);
      final labels = host
          .toLowerCase()
          .split('.')
          .where((label) => label.isNotEmpty)
          .toList();
      if (labels.isEmpty) continue;
      final countrySecondLevel =
          labels.length >= 3 &&
          labels.last.length == 2 &&
          labels[labels.length - 2].length <= 3;
      final keep = countrySecondLevel ? 3 : 2;
      found.add(
        labels.skip(labels.length < keep ? 0 : labels.length - keep).join('.'),
      );
    }
    return found.toList()..sort();
  }
}
