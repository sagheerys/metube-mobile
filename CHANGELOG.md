# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project
follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Both apps share this file: an entry says which one it affects when it affects
only one.

## [Unreleased]

### Added

- **Follow a channel and the server keeps it for you.** Settings now has
  "Subscriptions": paste a channel or playlist link, choose a quality and
  how often to look, and MeTube downloads each new video by itself, into
  the same library as everything else. Only what appears from then on is
  fetched — the videos already on the channel are left where they are. Each
  one can be paused, renamed, checked on the spot, or limited to titles
  matching a word you give. A MeTube too old to have subscriptions says so
  instead of showing an empty list. MeTube Super.
- **And it tells you when something arrives.** One notice for the batch,
  not one per clip, naming what came; it can be switched off in settings.
  It appears the next time the app reaches the server rather than while
  the phone is asleep, and it never repeats a batch, never announces what
  you downloaded yourself, and says nothing at all on a first run.
  MeTube Super.
- **Cookies can be sent from the phone.** For the platforms that refuse to
  hand a video over without a login, Settings now takes a cookies file
  exported from your browser and passes it to the server — and shows
  whether the server has one, and removes it again. The file is never
  stored on the phone. MeTube Super.
- **Cookies for several platforms at once.** The server keeps a single
  cookies file and each upload replaces it whole, so sending one platform's
  file signed the previous one out. Pick all their files together and they
  are merged on the phone, in memory, into the one file the server keeps;
  the screen now says plainly that an upload replaces what was there, how
  to pick more than one file, and — once sent — which sites went in.
  MeTube Super.
- **A followed channel opens from the list.** Tap its name, or choose
  "Open channel" from its menu, and it opens in its own app. MeTube Super.
- **The glow behind the cover moves while the sound plays.** In the audio
  player, two embers in the app's own colour circle the cover in opposite
  directions, meeting and parting somewhere new each time, and settle
  when you pause. It stays still if
  animations are turned off in Android. Both apps.

### Fixed

- **A song you skip to starts from the top.** Skipping through a music
  playlist brought every song back half-way in, because every clip
  resumed where it was last left. Only something ten minutes or longer —
  a lecture, an episode — now picks up where it was; the video player
  still resumes any clip, and reopening the app still continues the song
  that was playing. Both apps.
- **"Previous" restarts the song first.** Past three seconds one press
  goes back to the start and a second press to the song before, as car
  stereos and other music players expect. Both apps.
- **A paused playlist comes back whole.** Fifteen minutes after a pause
  the app releases the phone; a later "play" from the car or earphones
  then started the last clip alone, outside its playlist, with nothing
  next. It now brings the whole list back, and the mini player returns
  with it when the app is opened. Both apps.
- **A clip added to or removed from a playlist shows at once**, instead of
  after the app was closed. Both apps.
- **In Arabic, the video's rewind and forward buttons now sit the way its
  timeline runs**, matching the double tap. Both apps.

- **A stream that keeps dropping is now given up on instead of retried for
  ever.** Waiting out a hiccup was right; the budget for it came back with
  any successful load, and a source that loads, plays a second and drops
  produces exactly the pair that defeats that — each failure answered by a
  retry and each retry refilling the budget, with the screen holding the
  phone awake and saying nothing. The budget now comes back for playing
  rather than for loading. Both apps.
- **A channel's name no longer comes apart from the time beside it.** A name
  written in one language and a phrase in another have no agreed place for
  the separator between them, so "channel · 5 minutes ago" and "Unfollow
  …?" both rearranged themselves. Every name the app did not write itself —
  a channel, a playlist, a tag, a title — is now kept whole, whichever
  language the interface is in. Both apps.
- **What is new in an update now reads as text rather than as a file.** The
  release notes arrive from the release page in Markdown, and the update
  sheet printed the stars, the dashes and the link brackets along with the
  words. Both apps.
- **A missing cover no longer leaves a black square in the player's
  queue.** The clip's icon was drawn only when there was no cover at all, so
  a cover that existed and failed to load — a cleared cache, an extracted
  cover deleted with its file — left an empty box instead. Both apps.
- **A download is now followed by the name the server gave it, so it can no
  longer finish on the server while the app waits forever.** The server
  files a clip under the address the site redirects to, which is often not
  the address you pasted — a Reddit link from the share button, a Vimeo
  clip taken from its author's page. The app was watching for the address
  it sent, so the file arrived, the library showed it, and the card sat at
  0% until it gave up; in Lite nothing was pulled to the phone and nothing
  was cleaned off the server. The app now notes what is on the server
  before it asks for anything, and follows whatever single thing its own
  request changed. If two things change at once — someone else using the
  same server in the same seconds — it does not guess, and behaves as
  before. **This also stops a clip you downloaded yourself being announced
  back to you** as something a channel had just published. Both apps.
- **A Reddit link shared from the Reddit app now finishes instead of hanging
  at nothing.** The clip downloaded on the server perfectly, and the app's
  counter never moved: MeTube files an item under the URL yt-dlp ended at,
  and the share button hands out a short link that redirects — so the app
  spent its whole polling budget waiting for a URL the server had never
  heard of. Lite therefore never pulled the file and never cleaned the
  server, and Super showed a stuck card beside a clip that was already in
  its library. Reddit's short forms are now resolved before the download is
  requested, as TikTok's and Facebook's already were. Both apps.
- **A Vimeo clip taken from its author's page, likewise.** `vimeo.com/name/
  title` is redirected to the clip's number, and the number is what the
  server files. Both apps.
- **Cancelling such a download no longer leaves it running on the server.**
  The cleanup looked for the address the app had sent, which was not the
  one the item was filed under, so nothing was found and the server carried
  on downloading a file nobody would come back for. Both apps.
- **The floating add button can no longer be pushed off the screen by its
  own label.** It had no width of its own, so a long word at an enlarged
  system font size ran past the right edge of a small screen. Today's
  labels are short enough that nobody saw it; the next language's might
  not have been. Both apps.
- **The favourites tag no longer shows up as one of yours.** Favourites are
  stored as a system tag, and once any real tag existed the library offered
  `# __favorites__` as a filter beside it, as did "your tags" and the
  manage-tags sheet. MeTube Super.

### Changed

- **A platform that wants a login now names the screen that fixes it.** The
  message said the server's administrator should refresh the cookies, which
  was the only true answer while no app could do it. In Super the person
  reading it is that administrator, so it now points at Settings → Cookies.
  Lite keeps the old wording on purpose: it has no such screen, and whoever
  holds it is usually not whoever runs the server. MeTube Super.

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

[Unreleased]: https://github.com/sagheerys/metube-mobile/compare/v2.1.0...HEAD
[2.1.0]: https://github.com/sagheerys/metube-mobile/compare/v2.0.2...v2.1.0
[2.0.2]: https://github.com/sagheerys/metube-mobile/compare/v2.0.1...v2.0.2
[2.0.1]: https://github.com/sagheerys/metube-mobile/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/sagheerys/metube-mobile/releases/tag/v2.0.0
