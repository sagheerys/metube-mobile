import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// م-18: قيمة فهرس الأغلفة في Lite قد تكون **مسار ملف محلي مولّد**
/// (لقطة إطار أو غلاف صوت مضمّن — راجع `MediaProbe.kt`) أو رابط منصة
/// محفوظاً وقت التحميل. الفرق يُقرأ من القيمة نفسها لا من عمود إضافي.
Widget artworkFor(String? value, {BoxFit fit = BoxFit.cover}) {
  if (value == null || value.isEmpty) return const SizedBox.shrink();
  if (value.startsWith('http')) {
    return CachedNetworkImage(
      imageUrl: value,
      fit: fit,
      errorWidget: (_, _, _) => const SizedBox.shrink(),
    );
  }
  return Image.file(
    File(value),
    fit: fit,
    // الكاش نُظّف أو الملف حُذف ⇒ بطاقة بلا غلاف، لا مربع خطأ أحمر.
    errorBuilder: (_, _, _) => const SizedBox.shrink(),
  );
}
