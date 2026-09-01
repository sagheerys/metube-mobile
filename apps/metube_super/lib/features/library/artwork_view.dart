import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// م-18: قيمة الغلاف قد تكون **مسار ملف محلي مولَّد** (لقطة إطار أو
/// غلاف صوت مضمّن — راجع `MediaProbe.kt`) أو رابط شبكة يحتاج ترويسات
/// مصادقة. الفرق يُقرأ من القيمة نفسها.
///
/// يُرجع **null** لا `SizedBox` حين لا غلاف: البطاقة عندها ترسم أيقونتها
/// البديلة، وإرجاع ودجت فارغة كان يترك مربعاً أصمّ بلا شيء.
Widget? artworkFor(
  String? value, {
  Map<String, String>? headers,
  BoxFit fit = BoxFit.cover,
}) {
  if (value == null || value.isEmpty) return null;
  if (value.startsWith('http')) {
    return CachedNetworkImage(
      imageUrl: value,
      httpHeaders: headers,
      fit: fit,
      errorWidget: (_, _, _) => const SizedBox.shrink(),
    );
  }
  return Image.file(
    File(value),
    fit: fit,
    // الكاش نُظّف أو الملف حُذف ⇒ بطاقة بلا غلاف لا مربع خطأ.
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}
