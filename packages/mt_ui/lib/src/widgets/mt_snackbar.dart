import 'package:flutter/material.dart';

import '../theme/mt_theme.dart';

enum MTSnackType { info, success, error }

/// How long a snack bar stays: one duration for all of them, with or
/// without an action.
const mtSnackDuration = Duration(seconds: 4);

/// One SnackBar style, an inverted slab with a meaningful icon and an
/// optional undo.
void showMTSnack(
  BuildContext context,
  String message, {
  MTSnackType type = MTSnackType.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = mtSnackDuration,
}) => showMTSnackOn(
  ScaffoldMessenger.of(context),
  message,
  type: type,
  actionLabel: actionLabel,
  onAction: onAction,
  themeContext: context,
  duration: duration,
);

/// The same, with a **pre-captured** messenger. Used when the original
/// context has already been deactivated, such as a bottom sheet that just
/// closed: looking up `ScaffoldMessenger` through a deactivated context
/// trips the `_dependents.isEmpty` assertion.
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
        // **It dismisses itself even when it has an action** (field report
        // 2026-09-04: "the notices that appear over the add-link button
        // never go away"). In Flutter, `persist = persist ?? action !=
        // null`, so every bar with a button, such as "download started ·
        // change quality", stayed **forever** until the user swiped it
        // away, while "added to favourites" with no action vanished after
        // four seconds. The decision: one duration for all.
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
