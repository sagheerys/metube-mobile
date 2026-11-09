import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../shell/window_controls.dart';
import 'window_frame.dart';
import 'window_placement.dart';

/// [WindowControls] over window_manager, plus the runner's Snap Layouts
/// channel (`windows/runner/flutter_window.cpp`).
///
/// **Why the runner is involved at all:** Windows 11 shows Snap Layouts
/// only over a window's native maximize button, and with the title bar
/// drawn by Flutter there is none. So the drawn button reports where it
/// is, and the runner answers Windows' hit test there as a maximize
/// button. Windows then owns that spot, its clicks included, and tells us
/// about the hover so the drawn button can light up.
class WindowManagerControls with WindowListener implements WindowControls {
  WindowManagerControls._() {
    _snap.setMethodCallHandler((call) async {
      if (call.method == 'hover') {
        maximizeHovered.value = call.arguments == true;
      }
    });
    windowManager.addListener(this);
  }

  static Future<WindowManagerControls> create() async {
    final controls = WindowManagerControls._();
    controls.maximized.value = await windowManager.isMaximized();
    await controls._readWorkArea();
    return controls;
  }

  static const _snap = MethodChannel('metube_ember/snap');

  @override
  final ValueNotifier<bool> maximized = ValueNotifier(false);
  @override
  final ValueNotifier<bool> maximizeHovered = ValueNotifier(false);

  @override
  void minimize() => unawaited(windowManager.minimize());

  @override
  void toggleMaximize() => unawaited(
    maximized.value ? windowManager.unmaximize() : windowManager.maximize(),
  );

  @override
  void close() => unawaited(windowManager.close());

  @override
  void startDragging() => unawaited(windowManager.startDragging());

  @override
  void reportMaximizeButton(Rect physical) => unawaited(
    _snap.invokeMethod('setMaxButtonRect', [
      physical.left.round(),
      physical.top.round(),
      physical.right.round(),
      physical.bottom.round(),
    ]),
  );

  @override
  final ValueNotifier<Size?> workArea = ValueNotifier(null);

  @override
  final ValueNotifier<bool> fullScreen = ValueNotifier(false);

  @override
  void setFullScreen(bool on) => unawaited(_setFullScreen(on));

  /// The state is set here, not left to the window's events: on Windows
  /// window_manager sends none for full screen (measured: the window
  /// filled the screen while the app still drew its frame, and Esc, which
  /// asks this state, could not bring it back).
  Future<void> _setFullScreen(bool on) async {
    await windowManager.setFullScreen(on);
    fullScreen.value = on;
  }

  @override
  void onWindowEnterFullScreen() => fullScreen.value = true;
  @override
  void onWindowLeaveFullScreen() => fullScreen.value = false;

  @override
  final ValueNotifier<int> closeRequests = ValueNotifier(0);

  // Every close reaches here, the window's own button and Windows' alike,
  // since the app holds the close back to decide (see EmberWindow).
  @override
  void onWindowClose() => closeRequests.value++;

  /// The smallest the full window may be, kept while the small card sets
  /// its own.
  Size _minimum = Size.zero;

  @override
  void setMinimumSize(Size logical) {
    _minimum = logical;
    if (!mini.value) unawaited(_setMinimum(logical));
  }

  Future<void> _setMinimum(Size logical) async {
    await windowManager.setMinimumSize(logical);
    if (await windowManager.isMaximized()) return;
    final size = await windowManager.getSize();
    if (size.width < logical.width || size.height < logical.height) {
      await windowManager.setSize(
        Size(
          size.width < logical.width ? logical.width : size.width,
          size.height < logical.height ? logical.height : size.height,
        ),
      );
    }
  }

  @override
  final ValueNotifier<bool> mini = ValueNotifier(false);

  /// The window as it was before the small card, to come back to.
  Rect? _before;
  bool _wasMaximized = false;

  /// The card's size while the window is the card; null otherwise.
  Size? _card;

  @override
  void setMini(Size? logical, {bool stretch = false}) =>
      unawaited(_setMini(logical, stretch: stretch));

  /// The card sits in the corner by the clock, over everything. The card
  /// is drawn before the window shrinks and the page after it grows back,
  /// so neither is ever laid out in the other's size.
  ///
  /// **The card is never maximized** (Win+Up, a drag to the top edge,
  /// Snap): maximized, the card was stretched over the whole screen, and
  /// the window that came back from it was broken. **A picture card can be
  /// stretched by its edges** (owner's request 2026-11-10), at its own
  /// shape, from its starting size up to half the screen's width; the
  /// sound strip keeps its one size.
  Future<void> _setMini(Size? logical, {bool stretch = false}) async {
    if (logical == null) {
      if (!mini.value) return;
      _card = null;
      await windowManager.setAlwaysOnTop(false);
      await windowManager.setAspectRatio(0);
      await windowManager.setMaximumSize(_unbounded);
      await windowManager.setResizable(true);
      await windowManager.setMaximizable(true);
      await windowManager.setMinimumSize(_minimum);
      if (_before case final before?) await windowManager.setBounds(before);
      if (_wasMaximized) await windowManager.maximize();
      mini.value = false;
      return;
    }
    if (!mini.value) {
      if (fullScreen.value) await _setFullScreen(false);
      _wasMaximized = await windowManager.isMaximized();
      if (_wasMaximized) await windowManager.unmaximize();
      _before = await windowManager.getBounds();
      mini.value = true;
      await windowManager.setMaximizable(false);
    }
    _card = logical;
    _stretch = stretch;
    await _placeCard(logical);
  }

  Future<void> _placeCard(Size logical) async {
    final bounds = await windowManager.getBounds();
    final areas = [
      for (final d in await screenRetriever.getAllDisplays()) workAreaOf(d),
    ];
    final area = workAreaHolding(bounds, areas) ?? bounds;
    await windowManager.setResizable(_stretch);
    if (_stretch) {
      final widest = area.width / 2 > logical.width
          ? area.width / 2
          : logical.width;
      await windowManager.setAspectRatio(logical.width / logical.height);
      await windowManager.setMaximumSize(
        Size(widest, widest * logical.height / logical.width),
      );
    } else {
      await windowManager.setAspectRatio(0);
      await windowManager.setMaximumSize(logical);
    }
    await windowManager.setMinimumSize(logical);
    await windowManager.setBounds(
      Rect.fromLTWH(
        area.right - logical.width - _cardMargin,
        area.bottom - logical.height - _cardMargin,
        logical.width,
        logical.height,
      ),
    );
    await windowManager.setAlwaysOnTop(true);
  }

  /// Should Windows maximize the card all the same, it goes back to its
  /// corner at its size.
  Future<void> _unmaximizeCard(Size card) async {
    await windowManager.unmaximize();
    await _placeCard(card);
  }

  static const _cardMargin = 16.0;

  /// Whether the card in place can be stretched by its edges.
  bool _stretch = false;

  /// No limit worth the name: the plugin has no way to take a maximum size
  /// back once set, so leaving the card sets one no screen reaches.
  static const _unbounded = Size(100000, 100000);

  /// Which screen the window is on, by most overlap.
  Future<void> _readWorkArea() async {
    final bounds = await windowManager.getBounds();
    final areas = [
      for (final d in await screenRetriever.getAllDisplays()) workAreaOf(d),
    ];
    workArea.value = workAreaHolding(bounds, areas)?.size ?? workArea.value;
  }

  /// Moving fires once the drag ends, so a window carried to a smaller
  /// screen is measured there.
  @override
  void onWindowMoved() => unawaited(_readWorkArea());

  @override
  void onWindowMaximize() {
    maximized.value = true;
    final card = _card;
    if (mini.value && card != null) unawaited(_unmaximizeCard(card));
  }

  @override
  void onWindowUnmaximize() => maximized.value = false;
  @override
  void onWindowRestore() =>
      unawaited(windowManager.isMaximized().then((v) => maximized.value = v));
}
