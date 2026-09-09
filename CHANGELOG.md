# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Both apps share this file: an entry says which one it affects when it affects
only one.

## [Unreleased]

Nothing yet.

## [2.0.0]

The first public release. The two apps were rebuilt from nothing, sharing one
core rather than duplicating it, so a defect fixed once is fixed in both.

### Added

- **A four-stage download pipeline** — add, poll, pull, then apply the delete
  policy — with per-task progress, cancellation that leaves nothing behind, and
  errors classified rather than swallowed.
- **MeTube Lite**: pulls each file to the device and then cleans the server, so
  a family server does not fill up. Wi-Fi-only downloads, with tasks that wait
  and resume by themselves.
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

[Unreleased]: https://github.com/sagheerys/metube-mobile/compare/v2.0.0...HEAD
[2.0.0]: https://github.com/sagheerys/metube-mobile/releases/tag/v2.0.0
