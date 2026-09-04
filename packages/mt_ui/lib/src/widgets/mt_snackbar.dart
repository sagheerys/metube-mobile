import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';

enum MTSnackType { info, success, error }

/// زمن ظهور الشريط — واحد لكل الأشرطة، بفعل أو بلا فعل.
const mtSnackDuration = Duration(seconds: 4);

/// SnackBar موحد «قطعة معكوسة» بأيقونة دلالية وزر تراجع اختياري.
void showMTSnack(
  BuildContext context,
  String message, {
  MTSnackType type = MTSnackType.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = mtSnackDuration,
}) =>
    showMTSnackOn(
      ScaffoldMessenger.of(context),
      message,
      type: type,
      actionLabel: actionLabel,
      onAction: onAction,
      themeContext: context,
      duration: duration,
    );

/// نفسه بمُراسِل **ملتقط مسبقاً**: يُستعمل حين يكون السياق الأصلي قد
/// أُبطِل (ورقة سفلية أُغلقت للتو) — البحث عن `ScaffoldMessenger` بسياق
/// مُبطَّل يفجّر تأكيد `_dependents.isEmpty` (درس المرحلتين 6 و7).
void showMTSnackOn(
  ScaffoldMessengerState messenger,
  String message, {
  MTSnackType type = MTSnackType.info,
  String? actionLabel,
  VoidCallback? onAction,
  BuildContext? themeContext,
  Duration duration = mtSnackDuration,
}) {
  final x = MTThemeX.of(themeContext ?? messenger.context);
  final (icon, tint) = switch (type) {
    MTSnackType.success => (Icons.check_circle_rounded, x.palette.ok),
    MTSnackType.error => (Icons.error_rounded, x.palette.err),
    MTSnackType.info => (Icons.info_rounded, x.palette.miniInk),
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        // **يختفي وحده حتى مع وجود فعل** (بلاغ المالك 2026-09-04:
        // «الإشعارات التي تأتي فوق زر إضافة رابط لا تذهب»).
        // في Flutter: `persist = persist ?? action != null` — فكل شريط
        // له زر (مثل «بدأ التحميل · تغيير الجودة») كان **يبقى للأبد**
        // حتى يُزيحه المستخدم بيده، بينما «أُضيف للمفضلة» بلا فعل
        // يختفي بعد أربع ثوانٍ. القرار: زمن واحد للجميع.
        persist: false,
        duration: duration,
        content: Row(
          children: [
            Icon(icon, size: 18, color: tint),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        action: actionLabel == null
            ? null
            : SnackBarAction(
                label: actionLabel,
                textColor: x.palette.accentInk,
                onPressed: onAction ?? () {},
              ),
      ),
    );
}
