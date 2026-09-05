import 'package:mt_ui/mt_ui.dart';

import '../models/play_mode.dart';

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
///
/// **معزول الاتجاه**: السالب محرف محايد، ففي فقرة عربية كان يتذيّل
/// النص فيُقرأ «50:49-» (لقطة المالك 2026-09-05).
String mtFormatRemaining(Duration position, Duration? total) {
  if (total == null || total <= Duration.zero) return '--:--';
  return mtLtrRun('-${mtFormatDuration(total - position)}');
}

/// سرعة التشغيل: `1.0` لا `1`، و`1.25` لا `1.250` — يشترك فيها مشغلا
/// الصوت والفيديو فلا يختلف شكل الرقم بين شاشتين تعرضان نفس الإعداد.
String mtFormatSpeed(double speed) =>
    speed == speed.roundToDouble() ? speed.toStringAsFixed(1) : '$speed';

/// السرعة التالية في الدورة — **كانت منسوخة ثلاث مرات** (شاشة الصوت،
/// ورقة معلومات الفيديو، زر السرعة الجديد). ثلاث نسخ لدالة واحدة تعني
/// أن تعديل قائمة السرعات مستقبلاً سيُطبَّق في مكان أو اثنين لا ثلاثة.
double mtNextSpeed(double current) {
  final options = PlaybackSpeeds.options;
  final index = options.indexWhere((s) => (s - current).abs() < 0.01);
  return options[(index + 1) % options.length];
}
