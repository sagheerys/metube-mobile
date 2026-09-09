/// Semantic version comparison, the basis for deciding "is there anything
/// newer?".
///
/// **Why strings are not compared directly**: `'2.10.0'.compareTo('2.9.0')`
/// returns negative, because a string comparison sees `'1' < '9'`, so the
/// user stays on 2.9.0 forever. Every such decision passes through here.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch, {this.preRelease});

  final int major;
  final int minor;
  final int patch;

  /// Whatever follows `-`, such as `beta.1`. `null` means a stable release.
  final String? preRelease;

  /// Accepts `2.1.0`, `v2.1.0`, `2.1.0+7` and `2.1.0-beta.1`.
  ///
  /// **The build number `+7` is dropped on purpose**: it is Android's
  /// internal counter (`versionCode`), and two builds of the same `2.1.0`
  /// are not an update to each other as far as the user is concerned.
  static AppVersion? tryParse(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    // Build number first: `2.1.0-beta+7` is cut at the `+`, not at the `-`.
    final plus = s.indexOf('+');
    if (plus >= 0) s = s.substring(0, plus);
    String? pre;
    final dash = s.indexOf('-');
    if (dash >= 0) {
      pre = s.substring(dash + 1);
      s = s.substring(0, dash);
      if (pre.isEmpty) pre = null;
    }
    final parts = s.split('.');
    if (parts.isEmpty || parts.length > 3) return null;
    final nums = <int>[];
    for (final part in parts) {
      final n = int.tryParse(part);
      // Reject empty, negative and alphabetic parts. No guessing.
      if (n == null || n < 0) return null;
      nums.add(n);
    }
    return AppVersion(
      nums[0],
      nums.length > 1 ? nums[1] : 0,
      nums.length > 2 ? nums[2] : 0,
      preRelease: pre,
    );
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);
    // **A pre-release ranks below the stable release** (SemVer §11.3):
    // `2.1.0-beta.1 < 2.1.0`. Without it, somebody on the stable build
    // would be offered an "update" to a pre-release older than what they
    // have.
    final a = preRelease;
    final b = other.preRelease;
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return a.compareTo(b);
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;
  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator >=(AppVersion other) => compareTo(other) >= 0;
  bool operator <=(AppVersion other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      other is AppVersion && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch, preRelease);

  @override
  String toString() {
    final base = '$major.$minor.$patch';
    return preRelease == null ? base : '$base-$preRelease';
  }
}
