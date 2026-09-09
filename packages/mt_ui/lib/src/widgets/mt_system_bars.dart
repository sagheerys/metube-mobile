import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/tokens.dart';

/// **The safe bottom padding inside a bottom sheet.**
///
/// A bottom sheet always reaches the edge of the screen: `useSafeArea` in
/// `showModalBottomSheet` is literally `SafeArea(bottom: false)`. It
/// guards against the camera cutout at the top and does not guard the
/// bottom at all. So with **three-button navigation** rather than
/// gestures, the last element disappears under the buttons: "start
/// download" was cut in half (field report 2026-09-04).
///
/// The sum is correct and not double-counted: when the keyboard appears,
/// `viewInsets` swallows the button bar and `padding.bottom` becomes zero;
/// when it hides, the reverse.
double mtSheetBottomPad(BuildContext context, [double extra = MTSpace.xl]) =>
    MediaQuery.viewInsetsOf(context).bottom +
    MediaQuery.paddingOf(context).bottom +
    extra;

/// **Transparent system bars with no contrast scrim**, so the app's colour
/// reaches the very edge of the screen.
///
/// Android 15+ forces a black or white contrast scrim behind the three
/// navigation buttons unless the app says it does not want one, which
/// shows as a band of a different colour immediately below the app's own
/// bar: a visible cut in both themes (field report 2026-09-04). With
/// gestures it never appears, because that bar is thin and transparent
/// already, which is why it went unseen for so long.
///
/// Icon brightness follows the theme: dark icons over cream by day, light
/// icons over espresso by night. Full-screen players declare their own
/// style deeper in the tree and win over this one, since the nearest
/// `AnnotatedRegion` takes precedence.
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
        // iOS reads the background brightness rather than the icons', so
        // this is
        // inverted on purpose.
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
