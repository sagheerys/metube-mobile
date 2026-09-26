# audio_service 0.18.19, patched

An unmodified copy of [audio_service](https://pub.dev/packages/audio_service)
0.18.19 (MIT, see `LICENSE`), with one change, used by both apps through
`dependency_overrides` in the workspace `pubspec.yaml`. The `example/` and
`test/` folders of the original are left out.

## The change

`AudioService.onDestroy()` clears the static `listener` that carries media
commands to Dart, and only `AudioServicePlugin` sets it again, when a Flutter
engine attaches. A service destroyed and recreated while the engine lives
therefore dropped every command: the media session still showed the app's
state, but pause, play and the other buttons from the notification, the lock
screen, a car or headphones reached nothing, until the app process was
restarted.

The patch adds `AudioService.hasListener()`, which fetches the plugin's live
handler interface (`AudioServicePlugin.currentListener()`) whenever the
listener is missing, and uses it in place of every `listener == null` guard,
so a command reaches Dart at the moment it arrives.

Files touched: `android/src/main/java/com/ryanheise/audioservice/AudioService.java`
and `AudioServicePlugin.java`. Nothing else differs from the published package.

Drop this copy and the override once an upstream release fixes it.
