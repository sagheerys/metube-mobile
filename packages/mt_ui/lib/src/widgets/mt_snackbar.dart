import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';

enum MTSnackType { info, success, error }

/// SnackBar موحد «قطعة معكوسة» بأيقونة دلالية وزر تراجع اختياري.
void showMTSnack(
  BuildContext context,
  String message, {
  MTSnackType type = MTSnackType.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  final x = MTThemeX.of(context);
  final (icon, tint) = switch (type) {
    MTSnackType.success => (Icons.check_circle_rounded, x.palette.ok),
    MTSnackType.error => (Icons.error_rounded, x.palette.err),
    MTSnackType.info => (Icons.info_rounded, x.palette.miniInk),
  };
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
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
