import 'dart:io';
import 'dart:math' show max;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// م-18: قيمة فهرس الأغلفة في Lite قد تكون **مسار ملف محلي مولّد**
/// (لقطة إطار أو غلاف صوت مضمّن — راجع `MediaProbe.kt`) أو رابط منصة
/// محفوظاً وقت التحميل. الفرق يُقرأ من القيمة نفسها لا من عمود إضافي.
///
/// يُرجع **null** لا `SizedBox` حين لا غلاف: البطاقة عندها ترسم أيقونتها
/// البديلة، وإرجاع ودجت فارغة كان يترك مربعاً أصمّ بلا شيء.
///
/// [decodeWidth] **بالبكسل الفيزيائي**: مصغرة يوتيوب 1280×720 تشغل
/// ~3.5MB في ذاكرة الصور مهما صغُر الصندوق الذي تُرسم فيه — وأربعون
/// بطاقة مرئية تعني عشرات الميغابايت بلا فائدة. الفك عند حجم العرض
/// يقصّها إلى جزء من ذلك. تُحسب بـ [mtDecodeWidth] لا يدوياً.
Widget? artworkFor(
  String? value, {
  BoxFit fit = BoxFit.cover,
  int? decodeWidth,
}) {
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http')) {
    return CachedNetworkImage(
      imageUrl: value,
      fit: fit,
      memCacheWidth: decodeWidth,
      errorWidget: (_, _, _) => const SizedBox.shrink(),
    );
  }
  return Image.file(
    File(value),
    fit: fit,
    cacheWidth: decodeWidth,
    // الكاش نُظّف أو الملف حُذف ⇒ بطاقة بلا غلاف، لا مربع خطأ أحمر.
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}

/// عرض فكّ الترميز بالبكسل الفيزيائي لصندوق [width]×[height] بـ`cover`.
///
/// **عرض الصندوق وحده لا يكفي**: `BoxFit.cover` يكبّر الصورة حتى يمتلئ
/// البعدان معاً، فمصغرة 16:9 في صندوق أعرض نسبةً (98×62) يُشتق مقياسها
/// من الارتفاع لا العرض. الفك عند 98 كان يعطي صورة ارتفاعها 55 ثم
/// تُمطّ إلى 62 — ضبابية أضفناها بأيدينا. الحد الآمن هو الأكبر من
/// العرض ومن `الارتفاع × 16/9`.
int mtDecodeWidth(BuildContext context, double width, [double? height]) {
  final needed = height == null ? width : max(width, height * 16 / 9);
  return (needed * MediaQuery.devicePixelRatioOf(context)).ceil();
}
