# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Both apps share this file: an entry says which one it affects when it affects
only one.

## [Unreleased]

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

[Unreleased]: https://github.com/sagheerys/metube-mobile/compare/v2.0.2...HEAD
[2.0.2]: https://github.com/sagheerys/metube-mobile/compare/v2.0.1...v2.0.2
[2.0.1]: https://github.com/sagheerys/metube-mobile/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/sagheerys/metube-mobile/releases/tag/v2.0.0
