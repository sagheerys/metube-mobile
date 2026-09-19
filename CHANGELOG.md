# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Both apps share this file: an entry says which one it affects when it affects
only one.

## [2.1.0] - 2026-09-19

### Added

- **The server card says what the server holds and what it runs.** Under
  the address: how many files are on it, how many are queued, and which
  MeTube version it reports — with a line when a newer MeTube release is
  out. The version comes from MeTube's own `/version` endpoint; a server
  that reports `dev`, or is too old to answer, is shown as "unknown" and is
  never told it is out of date. MeTube Super.
- **Lite finishes, at the next launch, the downloads it could not.** Every
  download is written down before it is sent, so when the app is killed
  from the recents list, stopped by the battery manager, or loses the
  network for a moment while the server keeps working, the next launch
  finds the finished file, pulls it to the phone and cleans it off the
  server — honouring "Wi-Fi only". Records older than a week are dropped.
  MeTube Lite.
- **Lite tells you when your server keeps the files it was told to
  delete.** MeTube removes a file only when `DELETE_FILE_ON_TRASHCAN=true`,
  and without it everything looks right while the disk fills up. After a
  cleanup, Lite checks with one small request whether the file is really
  gone, and says so in the settings until the container is fixed. MeTube
  Lite.

### Fixed

- **Deleting from the server no longer hides your copy on the phone.** The
  cleanup that follows a server delete removed the offline entry with
  everything else, so a downloaded copy vanished from the library while its
  file stayed on disk, invisible and unreclaimable. An item with a copy on
  the phone now stays in the library as a local item, with its tags,
  position and cover. MeTube Super.
- **One dropped connection no longer loses a Lite download.** Lite gave up
  on the first network error while waiting for the server, and the server
  then finished the file with nobody coming back for it. It now tolerates
  a short outage, as Super already did, and waits up to thirty minutes for
  a long download instead of ten. **Super waits thirty minutes too**: the
  ceiling is shared. MeTube Lite.
- **Deleting a local-only clip for good takes its data with it.** With
  server deletes now leaving the phone's copy in place, "delete local copy"
  on such a clip removed the file and left its tags, position, cover and
  playlist entries behind — the dead-playlist-entry defect of 2.0.0
  returning by another door. MeTube Super.
- **Backups no longer carry what belongs to one phone.** The record of a
  download in progress, restored on another phone, would have that phone
  pull the file and delete it from the server while the first was still
  pulling; and the "server keeps files" flag is a fact about one container.
  Neither is exported, and neither is accepted on import. Both apps.
- **Audio no longer dies a minute after a phone call.** Playing a playlist
  with the screen off, taking a call and hanging up left the current clip
  running and then silence: no next item, no notification, nothing to press.
  Measured on a Galaxy S22 Ultra (Android 16) by capturing the system log
  through the whole sequence. The call pauses playback, and the app used to
  leave its foreground service on every pause — which drops it to a cached
  process and releases the wake lock. When the call ended and playback
  resumed, Android refused to start that service again, because starting a
  foreground service **from the background** is forbidden since Android 12
  (`ForegroundServiceStartNotAllowedException`). Playback carried on
  unprotected: the process was frozen, the next item's request timed out,
  and the session stopped itself. The service now stays through a pause, so
  nothing has to be started again — verified by a second capture of the same
  sequence, in which the refusal, the freeze and the timeout are all absent.
  Both apps.
- **A dropped network is waited for instead of skipped.** Any playback error
  was treated as a broken item and skipped past, and five skips stopped the
  session — so one hiccup could end a playlist. A **stream** is now retried
  after 2, 5 and 10 seconds before it is given up on, while a local file
  that will not open is still skipped at once, since waiting for it would be
  waiting forever. Both apps.
- **A cover stored as a file shows on the lock screen.** Some audio clips
  had artwork inside the app and the app icon in the notification: a video's
  cover arrives from the server as a URL and passed, while an audio clip's
  cover is the one extracted from the file itself and written to disk, and
  a path without a scheme was discarded. Both apps.
- **"View all" leaves full screen before opening the playlist.** It used to
  open the playlist **over** the full-screen player, which stayed alive
  underneath: the picture vanished, the clip played on, and the phone stayed
  locked sideways over a screen that wanted neither. MeTube Super.

### Changed

- **A paused session now stops itself after fifteen minutes**, releasing the
  wake lock and clearing the notification. It is the other half of the
  foreground-service fix above: the service surviving a pause is what lets
  playback come back after a call, and the price is a wake lock held while
  paused. Fifteen minutes gives it back to whoever paused and walked away.
  A session restored at launch and never played is left alone; a call
  longer than fifteen minutes ends with the session stopped rather than
  resumed. Both apps.
- **Audio buffers two minutes ahead instead of fifty seconds.** Two minutes
  of audio is under 2 MB, and it rides out a lift, a tunnel or a Wi-Fi
  handover. Video is unchanged. Both apps.
- **The server's username and password say they are optional**, under the
  field rather than behind the help button. The sentence existed; it was
  shown only to someone who thought to press "?" — which is exactly the
  person who did not need it. Both apps.

## [2.0.2]

### Fixed

- **MeTube Lite: the library on a fresh install.** The app asked for the
  notification permission and never for the media one, though its downloads
  live in the phone's `Download` folder: the first scan came back
  `PathAccessException ... Permission denied, errno = 13` and the only way
  out was the system settings, which most people never find. Lite now asks
  for it when the first screen appears, the way the notification permission
  is asked, and the library offers the permission itself — with the settings
  screen as the second step when Android has stopped asking. The startup
  sweep of leftover partial files no longer throws on that same folder, in
  both apps.
- **MeTube Lite: a library hidden by that permission no longer looks empty.**
  Measured on a phone with the permission revoked: the folder still opened
  and still listed, and listed nothing, so twenty-eight downloads were
  reported as "no downloads yet" — no error, no dialog, nothing to act on.
  Whether the app may read the folder is now decided by the permission
  itself rather than by opening the folder, and an empty result with no
  permission is shown as what it is. Files that do list are shown whatever
  the permission API reports.

## [2.0.1]

### Fixed

- **Reels: a finger that slightly misses the progress bar no longer pauses
  the clip.** The bar's touch strip was 24 points, and a touch just beside it
  landed on tap-to-pause. It is now 48 points, and the side margins and the
  system inset below it belong to the bar. Both apps.
- **MeTube Super: a download keeps going after you leave the app.** Super had
  no background service, so seconds after leaving the app Android froze it:
  the progress notification stopped where it was, and the result appeared
  only when the app was opened again (measured: no request to the server for
  90 seconds). Super now holds the same foreground service as MeTube Lite,
  started with the first active download and stopped with the last, so it
  shows a "downloading in the background" notification only while a download
  runs. Polling also tolerates six network failures in a row instead of
  failing a download the server was still finishing. MeTube Lite is
  unchanged.
- **The first percent of a download no longer shows as 100%.** MeTube's
  `percent` is always 0 to 100, and values of 1 or less were read as
  fractions. Both apps.

### Changed

- **MeTube Super: the library stays usable without the server.** When the
  server cannot be reached, the videos saved on the phone, and the last server
  list if one had loaded, stay on screen under a banner that names the cause
  and offers a retry. The full-screen error remains when nothing is saved, and
  for a rejected password.

## [2.0.0]

The first public release. The two apps were rebuilt from nothing, sharing one
core rather than duplicating it, so a defect fixed once is fixed in both.

### Added

- **A four-stage download pipeline** — add, poll, pull, then apply the delete
  policy — with per-task progress, cancellation that leaves nothing behind, and
  errors classified rather than swallowed.
- **MeTube Lite**: pulls each file to the device and then cleans the server, so
  a shared server does not fill up. It reaches that server wherever it is — on
  the home network or through a tunnel — and downloads can be held to Wi-Fi by
  a setting that is off unless you turn it on, with tasks that wait and resume
  by themselves.
- **MeTube Super**: `/history` and the local index merged into one library,
  streaming straight from the server, tags, batch downloads, "make available
  offline", and automatic switching between a local and an external server URL.
- **Playback** shared by both: background audio with a media notification and
  lock-screen controls, a resume position keyed to the canonical URL so
  streaming and local playback share it, a mini player, and a shorts lane for
  portrait clips under three minutes.
- **Self-update**: the app checks GitHub for a newer release, downloads the
  APK, verifies it, and hands it to the system installer. Off nothing happens
  without confirmation, and a version can be skipped.
- **Backups** in plain JSON holding no secret, written atomically, rotating
  through the last seven, and able to read all three legacy formats.
- **Arabic and English** throughout, right-to-left first, with no hardcoded
  interface string.

### Fixed

Every defect below was found on a real device or against a real server, and
each one left behind a test that fails on the old code.

- Downloads that froze the whole queue when a single local error escaped
  unclassified.
- A ghost mini player that survived `stop()` because the media item and queue
  were not cleared with it.
- Two parallel players left running by a fast swipe, the first still playing
  audio behind the second's picture.
- Facebook and TikTok items matching the wrong history entry, so one file was
  handed to several items.
- Server filenames rejected as unsafe because yt-dlp truncates long titles with
  an ellipsis, which the old path guard read as traversal.
- The media notification vanishing in release builds, because resource
  shrinking removed drawables that `audio_service` looks up by name.
- Android's automatic backup carrying the secure-storage file to a new phone
  without the key that opens it.
- A dead URL freezing the thumbnail queue for over eighty seconds, because
  `MediaMetadataRetriever` retries ten times on an eight-second timeout.
- An album pasted as one link expanding into twenty downloads on the server,
  with only one of them pulled.

[2.1.0]: https://github.com/sagheerys/metube-mobile/compare/v2.0.2...v2.1.0
[2.0.2]: https://github.com/sagheerys/metube-mobile/compare/v2.0.1...v2.0.2
[2.0.1]: https://github.com/sagheerys/metube-mobile/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/sagheerys/metube-mobile/releases/tag/v2.0.0
