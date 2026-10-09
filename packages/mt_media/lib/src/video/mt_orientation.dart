import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// **The orientation policy (decision 2026-09-05): the app is portrait and
/// only the player rotates**, which is what YouTube itself does on a
/// phone.
///
/// The reason is not laziness: the library in landscape on a phone gives
/// two and a half rows with a top bar eating a third of the height, while
/// for video, landscape is its natural shape.
///
/// **A large screen is free** (tablets, 2026-10-10): a tablet stands on a
/// table sideways as often as it is held upright, and a library on its side
/// has room to spare. Android 16 already ignores a portrait request there,
/// so the lock only ever bit older tablets.
abstract final class MTOrientation {
  /// Whether the device is a large screen: its display's shorter side is
  /// at least 600 points. Phones keep every lock
  /// below exactly as before. Set by [start].
  static bool largeScreen = false;

  /// Decides the device class and applies the resting orientation: once at
  /// launch and again after the first frame. Before that frame the window
  /// has no size yet, and a tablet read as a phone opened every video in
  /// full screen (seen on the emulator 2026-10-10).
  static void start() {
    largeScreen = detectLargeScreen();
    unawaited(home());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final large = detectLargeScreen();
      if (large == largeScreen) return;
      largeScreen = large;
      unawaited(home());
    });
  }

  /// Reads the first display, or the window where the platform does not
  /// report the display. False while neither size is known.
  static bool detectLargeScreen() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) return false;
    final view = views.first;
    final display = view.display;
    // Android reports no display size (-1 by -1, measured 2026-10-10), so
    // the app's own window stands in for it there. At launch the window
    // fills the screen; it is empty until the first frame.
    final size = display.size.isEmpty
        ? view.physicalSize / view.devicePixelRatio
        : display.size / display.devicePixelRatio;
    return !size.isEmpty && size.shortestSide >= 600;
  }

  /// The orientation the app rests in when no player owns it: portrait on
  /// a phone, free on a large screen.
  static Future<void> home() => largeScreen ? allow() : lockPortrait();

  /// `portraitDown` is excluded on purpose: nobody holds a phone upside
  /// down.
  static const portrait = <DeviceOrientation>[DeviceOrientation.portraitUp];
  static const landscape = <DeviceOrientation>[
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];
  static const free = <DeviceOrientation>[
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ];

  static Future<void> lockPortrait() =>
      SystemChrome.setPreferredOrientations(portrait);
  static Future<void> lockLandscape() =>
      SystemChrome.setPreferredOrientations(landscape);
  static Future<void> allow() => SystemChrome.setPreferredOrientations(free);
}

/// **The rotation scope around the portrait player**: it unlocks portrait
/// while the player is open, opens full screen when the device is tilted,
/// and restores the lock on leaving.
///
/// `setPreferredOrientations([portraitUp])` in full screen's `dispose`
/// **pinned the entire app to portrait until it was killed** (field report
/// 2026-09-05: "landscape does not work and was never applied"): the call
/// is app-wide and does not end with the screen that made it.
class MTRotationScope extends StatefulWidget {
  const MTRotationScope({super.key, required this.open, required this.builder});

  /// Opens the full-screen page and completes when it closes. `byRotation`
  /// tells the page how it was entered: by a tilt, so it leaves on the
  /// opposite tilt, or by the button, so it forces landscape because the
  /// user may have rotation locked.
  final Future<void> Function(bool byRotation) open;

  final Widget Function(BuildContext context, VoidCallback openFullscreen)
  builder;

  @override
  State<MTRotationScope> createState() => _MTRotationScopeState();
}

class _MTRotationScopeState extends State<MTRotationScope> {
  bool _open = false;

  /// **Armed means ready to open on a tilt.** It is disarmed on every open
  /// and only rearms once portrait is seen again: without that, a user
  /// leaves full screen with the button while the device is still
  /// landscape, this scope sees landscape and reopens immediately, a loop
  /// with no way out.
  bool _armed = true;

  @override
  void initState() {
    super.initState();
    MTOrientation.allow();
  }

  @override
  void dispose() {
    MTOrientation.home();
    super.dispose();
  }

  Future<void> _openFullscreen(bool byRotation) async {
    if (_open || !mounted) return;
    _open = true;
    _armed = false;
    try {
      await widget.open(byRotation);
    } finally {
      _open = false;
      // A portrait clip's full screen stays upright, so no rotation comes
      // back to rearm the tilt: rearm here when the phone is upright.
      if (mounted &&
          MediaQuery.orientationOf(context) == Orientation.portrait) {
        _armed = true;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    // On a large screen landscape is a way of holding the device, not a
    // request for full screen: the player has a wide form of its own there.
    if (MTOrientation.largeScreen) {
      return widget.builder(context, () => _openFullscreen(false));
    }
    if (!landscape) {
      _armed = true;
    } else if (_armed && !_open) {
      // A route is never pushed from inside `build`.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openFullscreen(true);
      });
    }
    return widget.builder(context, () => _openFullscreen(false));
  }
}
