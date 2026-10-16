import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// **Back to the library tab, and only then what the share opens.**
///
/// A share always lands on the library. When the app was left on a screen
/// above the tabs (the video player, the audio screen, a batch), the move
/// closes that screen, but only on the next frame. A sheet opened in the
/// meantime belongs to the screen being closed and goes with it: the add
/// sheet showed for a fraction of a second, and the link was lost.
Future<void> landOnLibrary(StatefulNavigationShell shell) async {
  shell.goBranch(0);
  await WidgetsBinding.instance.endOfFrame;
}
