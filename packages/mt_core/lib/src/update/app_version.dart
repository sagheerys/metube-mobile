/// مقارنة إصدارات دلالية (SemVer) — أساس قرار «هل يوجد أحدث؟».
///
/// **لماذا لا تُقارَن النصوص مباشرة**: `'2.10.0'.compareTo('2.9.0')` يعطي
/// سالباً لأن المقارنة النصية ترى `'1' < '9'` — فيبقى المستخدم على 2.9.0
/// إلى الأبد. القرار يمرّ من هنا وحده.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch, {this.preRelease});

  final int major;
  final int minor;
  final int patch;

  /// ما بعد `-` مثل `beta.1` — و`null` تعني إصداراً مستقراً.
  final String? preRelease;

  /// يقبل `2.1.0` و`v2.1.0` و`2.1.0+7` و`2.1.0-beta.1`.
  ///
  /// **رقم البناء `+7` يُهمل عمداً**: هو عدّاد أندرويد الداخلي
  /// (`versionCode`)، ونسختان بنفس `2.1.0` وبناءين مختلفين ليستا
  /// تحديثاً لبعضهما في نظر المستخدم.
  static AppVersion? tryParse(String? raw) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('v') || s.startsWith('V')) s = s.substring(1);
    // رقم البناء أولاً: `2.1.0-beta+7` تقطع عند `+` لا عند `-`.
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
      // رفض الفراغ والسالب والحروف — لا تخمين.
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
    // **الإصدار التجريبي أدنى من المستقر** (قاعدة SemVer §11.3):
    // `2.1.0-beta.1 < 2.1.0`. بدونها يُعرض على من يملك المستقر
    // «تحديث» إلى تجريبي أقدم منه.
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
