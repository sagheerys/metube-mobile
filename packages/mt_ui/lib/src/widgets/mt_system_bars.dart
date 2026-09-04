import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/tokens.dart';

/// **المسافة السفلية الآمنة داخل ورقة سفلية.**
///
/// الورقة السفلية تمتد إلى حافة الشاشة دائماً: `useSafeArea` في
/// `showModalBottomSheet` هو `SafeArea(bottom: false)` — يحمي من فتحة
/// الكاميرا أعلى ولا يحمي من أسفل إطلاقاً. فمع **أزرار التنقل الثلاثة**
/// (بدل الإيماءات) يختفي آخر عنصر تحت الأزرار — «ابدأ التحميل» كان
/// مقطوعاً بنصفه (بلاغ المالك 2026-09-04).
///
/// الجمع صحيح لا تكرار فيه: حين تظهر لوحة المفاتيح يبتلع `viewInsets`
/// شريط الأزرار ويصير `padding.bottom` صفراً، وحين تُخفى يعود العكس.
double mtSheetBottomPad(BuildContext context, [double extra = MTSpace.xl]) =>
    MediaQuery.viewInsetsOf(context).bottom +
    MediaQuery.paddingOf(context).bottom +
    extra;

/// **أشرطة النظام شفافة بلا حجاب تباين** — فيمتد لون التطبيق إلى حافة
/// الشاشة نفسها.
///
/// أندرويد 15+ يفرض «حجاب تباين» أبيض/أسود خلف أزرار التنقل الثلاثة ما
/// لم يقل التطبيق إنه لا يريده، فيظهر شريطٌ لونه غير لون شريط التطبيق
/// أسفله مباشرة — قطعٌ بصري في الوضعين (بلاغ المالك 2026-09-04). مع
/// الإيماءات لا يظهر لأن الشريط رفيع وشفاف أصلاً، ولهذا لم يُرَ قبلاً.
///
/// لمعان الأيقونات يتبع الثيم: نهاراً أيقونات داكنة فوق الكريمي،
/// وليلاً فاتحة فوق الإسبريسو. المشغلات ملء الشاشة تعلن نمطها الخاص
/// أعمق في الشجرة فيغلب على هذا (`AnnotatedRegion` الأقرب يفوز).
class MTSystemBars extends StatelessWidget {
  const MTSystemBars({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final icons = dark ? Brightness.light : Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: icons,
        // iOS يقرأ سطوع الخلفية لا الأيقونات — معكوس عمداً.
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: icons,
        systemNavigationBarContrastEnforced: false,
      ),
      child: child,
    );
  }
}
