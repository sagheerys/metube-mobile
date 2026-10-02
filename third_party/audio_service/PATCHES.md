# audio_service 0.18.19, patched

An unmodified copy of [audio_service](https://pub.dev/packages/audio_service)
0.18.19 (MIT, see `LICENSE`), with two changes, used by both apps through
`dependency_overrides` in the workspace `pubspec.yaml`. The `example/` and
`test/` folders of the original are left out.

## The first change: commands after a service restart

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

## The second change: stop removes the notification

`AudioService.stop()` cancelled the notification and called `stopSelf()`
while the service was still in the foreground. With
`androidStopForegroundOnPause: false`, which the apps need so playback
survives a phone call, nothing had taken it out of the foreground first:
`cancel()` cannot remove a foreground service's notification, and
`stopSelf()` does nothing while the app is bound to the service. Closing the
player left a dead notification behind for as long as the app ran.

The patch calls `stopForeground(STOP_FOREGROUND_REMOVE)` and releases the
wake lock at the top of `stop()`. The next play starts the foreground again,
as it always did.

Files touched: `android/src/main/java/com/ryanheise/audioservice/AudioService.java`
and `AudioServicePlugin.java`. Nothing else differs from the published package.

Drop this copy and the override once an upstream release fixes it.
