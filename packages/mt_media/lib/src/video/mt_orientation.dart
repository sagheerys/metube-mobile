import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// **The orientation policy (decision 2026-09-05): the app is portrait and
/// only the player rotates**, which is what YouTube itself does on a
/// phone.
///
/// The reason is not laziness: the library in landscape on a phone gives
/// two and a half rows with a top bar eating a third of the height, while
/// for video, landscape is its natural shape. (A tablet is a question of
/// **width**, not orientation. That is a separate batch, and this lock
/// will be lifted for large screens then.)
abstract final class MTOrientation {
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
  static Future<void> allow() =>
      SystemChrome.setPreferredOrientations(free);
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
  const MTRotationScope({
    super.key,
    required this.open,
    required this.builder,
  });

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
    MTOrientation.lockPortrait();
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
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
