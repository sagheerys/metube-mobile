import 'dart:io';

import 'package:launch_at_startup/launch_at_startup.dart';

import '../identity.dart';

/// **Starting with Windows**: the app on the user's own start-up list
/// (no administrator), started with [arg] so it opens out of the way.
class WindowsStartup {
  WindowsStartup() {
    _use(quoted: true);
  }

  /// What the start-up list starts the app with.
  static const arg = '--startup';

  /// The program as the start-up list names it: in quotes. The app lives
  /// under "MeTube Ember", and an unquoted path with a space in it lets
  /// Windows try `…\MeTube.exe` first.
  static String program(String exe) => '"$exe"';

  void _use({required bool quoted}) => launchAtStartup.setup(
    appName: EmberIdentity.displayName,
    appPath: quoted
        ? program(Platform.resolvedExecutable)
        : Platform.resolvedExecutable,
    args: const [arg],
  );

  /// Whether the list has the app now; the user may have taken it off in
  /// Task Manager. An entry an earlier version wrote without quotes counts,
  /// and is written again with them.
  Future<bool> isOn() async {
    try {
      if (await launchAtStartup.isEnabled()) return true;
      _use(quoted: false);
      final old = await launchAtStartup.isEnabled();
      _use(quoted: true);
      if (old) await launchAtStartup.enable();
      return old;
    } on Object {
      return false;
    }
  }

  /// True when the list now says [on].
  Future<bool> set(bool on) async {
    try {
      on ? await launchAtStartup.enable() : await launchAtStartup.disable();
      return await isOn() == on;
    } on Object {
      return false;
    }
  }
}
