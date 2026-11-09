import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// What the drawn title bar asks of the window. The shell knows only this,
/// so it can be pumped in a test or a preview with no window behind it;
/// the window_manager implementation lives in `platform/`.
abstract interface class WindowControls {
  /// Whether the window fills the screen, for the restore icon and label.
  ValueListenable<bool> get maximized;

  /// Whether the pointer rests on the maximize button. Windows itself
  /// tracks this (the button answers as a native one, for Snap Layouts),
  /// so the hover arrives from the window rather than from Flutter.
  ValueListenable<bool> get maximizeHovered;

  void minimize();
  void toggleMaximize();
  void close();

  /// Hands a press on the title bar to Windows, which then drags the
  /// window, snaps it to an edge, or shakes the others away.
  void startDragging();

  /// Where the maximize button is, in physical pixels of the window's
  /// client area, so Windows can show Snap Layouts when hovering it.
  void reportMaximizeButton(Rect physical);

  /// The usable size of the screen the window is on (the taskbar left
  /// out), in logical pixels; it changes when the window moves to another
  /// screen. Null while unknown.
  ValueListenable<Size?> get workArea;

  /// The smallest the user may make the window, in logical pixels; it
  /// follows the interface size. A window already smaller grows to it.
  void setMinimumSize(Size logical);

  /// Whether the window covers the whole screen, taskbar included (F11).
  ValueListenable<bool> get fullScreen;

  void setFullScreen(bool on);

  /// Whether the window is the small card above every other (Ctrl+M).
  ValueListenable<bool> get mini;

  /// Makes the window the small card of [logical] size, above every other
  /// window; called again, it only resizes it. Null brings the window back
  /// as it was, maximized or not.
  ///
  /// With [stretch] its edges can be dragged to make it larger, keeping its
  /// shape, up to half the screen: a picture worth watching bigger. The
  /// sound strip keeps its one size.
  void setMini(Size? logical, {bool stretch = false});

  /// Counts the times the window was asked to close (its button, Alt+F4,
  /// the taskbar): with the tray on, each one hides it instead.
  ValueListenable<int> get closeRequests;
}

/// A window that does nothing: tests, previews and the component sheet.
class InertWindowControls implements WindowControls {
  @override
  final ValueNotifier<bool> maximized = ValueNotifier(false);
  @override
  final ValueNotifier<bool> maximizeHovered = ValueNotifier(false);

  /// Every call, in order, for tests to read.
  final List<String> calls = [];

  @override
  void minimize() => calls.add('minimize');
  @override
  void toggleMaximize() => calls.add('toggleMaximize');
  @override
  void close() {
    calls.add('close');
    closeRequests.value++;
  }

  @override
  final ValueNotifier<int> closeRequests = ValueNotifier(0);
  @override
  void startDragging() => calls.add('startDragging');

  /// Where the drawn maximize button last said it was; empty once it is
  /// gone from the screen.
  Rect? maximizeButton;

  @override
  void reportMaximizeButton(Rect physical) => maximizeButton = physical;

  /// Set by a test to stand for a screen.
  @override
  final ValueNotifier<Size?> workArea = ValueNotifier(null);

  @override
  final ValueNotifier<bool> fullScreen = ValueNotifier(false);

  @override
  void setFullScreen(bool on) {
    calls.add('fullScreen $on');
    fullScreen.value = on;
  }

  @override
  void setMinimumSize(Size logical) =>
      calls.add('minimum ${logical.width.round()}x${logical.height.round()}');

  @override
  final ValueNotifier<bool> mini = ValueNotifier(false);

  /// Whether the last card asked for could be stretched.
  bool stretchable = false;

  @override
  void setMini(Size? logical, {bool stretch = false}) {
    calls.add(
      logical == null
          ? 'mini off'
          : 'mini ${logical.width.round()}x${logical.height.round()}',
    );
    stretchable = logical != null && stretch;
    mini.value = logical != null;
  }
}
