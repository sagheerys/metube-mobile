/// تنسيق الأزمنة في المشغلات — أرقام جدولية بلا ترجمة (نفس الشكل بكل لغة).
String mtFormatDuration(Duration d) {
  final total = d.isNegative ? Duration.zero : d;
  final hours = total.inHours;
  final minutes = total.inMinutes.remainder(60);
  final seconds = total.inSeconds.remainder(60);
  final mm = hours > 0 ? minutes.toString().padLeft(2, '0') : '$minutes';
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

/// المتبقي بصيغة `-12:30` كما في مرجع شاشة الصوت.
String mtFormatRemaining(Duration position, Duration? total) {
  if (total == null || total <= Duration.zero) return '--:--';
  return '-${mtFormatDuration(total - position)}';
}
