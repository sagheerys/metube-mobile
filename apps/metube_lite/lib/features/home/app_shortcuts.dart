import 'package:flutter/services.dart';

/// Destinations for the long-press launcher shortcuts.
enum AppShortcut {
  /// Paste the clipboard link and start downloading it.
  paste,

  /// The library filtered to shorts.
  shorts,

  /// The library filtered to audio.
  audio;

  static AppShortcut? parse(String? name) {
    for (final value in AppShortcut.values) {
      if (value.name == name) return value;
    }
    return null;
  }
}

/// The bridge to the `consumeShortcut` channel.
///
/// **It is consumed once** on the native side: a shortcut is a momentary
/// intention, and leaving it in the intent re-runs it every time the user
/// returns to the app from recents.
///
/// The destination arrives in the intent's **action**
/// (`<pkg>.SHORTCUT_<NAME>`) rather than in a URL: any `data` in the
/// intent is hijacked by Flutter as a launch route and go_router throws
/// "Page Not Found" (caught on the emulator 2026-09-02).
class AppShortcuts {
  const AppShortcuts({this.channelName = 'metube_lite/media'});

  final String channelName;

  Future<AppShortcut?> consume() async {
    try {
      final name = await MethodChannel(channelName)
          .invokeMethod<String>('consumeShortcut');
      return AppShortcut.parse(name);
    } on Object {
      // A platform without the channel, tests or desktop, means no
      // shortcut.
      return null;
    }
  }
}
