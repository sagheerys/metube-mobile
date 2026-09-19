/// **What MeTube reports about itself** (§2.6): its own version and the
/// yt-dlp it carries.
///
/// The official image stamps the version with the build date, in the same
/// shape as the GitHub release tags (`2026.09.15`), so comparing the two is
/// a string comparison. An image built by hand reports `dev`, which is
/// neither older nor newer — it is unknown, and [isKnown] is what callers
/// ask before comparing anything.
class ServerVersion {
  const ServerVersion({required this.version, this.ytDlp});

  /// Verbatim, including `dev`. Never parsed into numbers: the dates are
  /// already ordered lexically, and a parser would only invent meaning for
  /// values it does not understand.
  final String version;

  /// The yt-dlp inside the container, shown but never compared: it moves on
  /// its own schedule and is updated by the image, not by the user.
  final String? ytDlp;

  /// Is this a version at all, rather than a placeholder?
  ///
  /// **The whole point of the distinction:** telling someone their server
  /// is out of date because it answered `dev` would be a lie, and telling
  /// them it is current would be a different lie.
  bool get isKnown => version.isNotEmpty && version != 'dev';

  /// **Is [latest] newer than this?** Only ever true when both sides are
  /// real dated versions.
  ///
  /// A plain string comparison, which is exactly right for `YYYY.MM.DD`
  /// and deliberately refuses anything else: a fork numbering its releases
  /// differently gets "unknown", not a wrong answer.
  bool isOlderThan(String latest) {
    if (!isKnown || !_isDated(latest) || !_isDated(version)) return false;
    return version.compareTo(latest) < 0;
  }

  static final RegExp _dated = RegExp(r'^\d{4}\.\d{2}\.\d{2}$');

  static bool _isDated(String value) => _dated.hasMatch(value.trim());

  /// Returns null for anything that is not a JSON map with a usable
  /// `version`, so a proxy's HTML error page cannot become a version.
  static ServerVersion? fromJson(dynamic decoded) {
    if (decoded is! Map) return null;
    final raw = decoded['version'];
    if (raw is! String || raw.trim().isEmpty) return null;
    final ytDlp = decoded['yt-dlp'];
    return ServerVersion(
      version: raw.trim(),
      ytDlp: ytDlp is String && ytDlp.trim().isNotEmpty ? ytDlp.trim() : null,
    );
  }

  @override
  String toString() => 'ServerVersion($version, yt-dlp: $ytDlp)';
}
