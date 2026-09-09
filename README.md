# MeTube Mobile

**English** · [العربية](README.ar.md)

[![CI](https://github.com/sagheerys/metube-mobile/actions/workflows/ci.yml/badge.svg)](https://github.com/sagheerys/metube-mobile/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/sagheerys/metube-mobile?color=C25E2E&label=release)](https://github.com/sagheerys/metube-mobile/releases/latest)
[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-Android-3DDC84.svg)](#requirements)
[![Flutter](https://img.shields.io/badge/Flutter-3.47.2-02569B.svg)](https://flutter.dev)

**Two Android apps for a self-hosted [MeTube](https://github.com/alexta69/metube)
server** — the yt-dlp web downloader you already run on your NAS or homelab.
Queue a link from your phone, watch the download happen, then keep the file on
the server and stream it, or pull it to the device and let the server clean
itself up. Written in Flutter as one monorepo, in Arabic and English, and free
software under the GPL.

> **Unofficial.** This project is not affiliated with, endorsed by, or connected
> to the MeTube project or its authors, nor to yt-dlp. It is an independent
> client that talks to a MeTube server over its HTTP API. The name "MeTube" is
> used only to say what these apps connect to.

| | **MeTube Lite** | **MeTube Super** |
|---|---|---|
| Made for | family and friends who just want the file | the person who runs the server |
| After a download completes | pulls it to the device, then **deletes it from the server** | **keeps it on the server** |
| Library | a scan of the local folder | `/history` + the local index, merged into one list |
| Playback | local files | streaming from the server **and** local files |
| Exclusive | an optional Wi-Fi-only rule, server cleanup | tags, batch downloads, "make available offline", server switching |

Both apps share the same core, media and design packages, and both ship in
**Arabic and English** with a right-to-left-first layout.

## Features

### In both apps

**Getting a link in.** Paste, or let the add button notice a link already on
the clipboard; share to the app from YouTube, TikTok or anything else — it
works from a cold start and takes several links at once. Links are recognised
and normalised across YouTube, X, Instagram, TikTok, Facebook, Vimeo, Reddit,
Twitch clips and SoundCloud, short links are followed (never downgrading HTTPS
to HTTP), and a playlist link opens the batch screen instead of queueing one
item.

**Downloading.** Four stages — hand the link to the server, follow its
progress, pull the file, then apply the app's delete policy — with live
percentages, one download at a time so a small server is not swamped, clean
cancellation that removes the partial file and tidies the server, three
retries with backoff for a dropped connection, and errors named rather than
swallowed (a platform asking for a login says so). Progress, completion and
failure each get a notification.

**Batch downloads.** A playlist arrives as a screen: every item with its
duration, select some or all, the total of what you picked, video or audio,
and one quality for the batch.

**The library.** Search by title; sort by date, name or size and keep the
choice; switch between rich cards and a compact list; pull to refresh; filter
video against audio; long-press for multi-select to delete, share, or add to a
playlist in one go. Thumbnails come from a disk and memory cache, are
generated from local video, read from the cover embedded in audio files, or
fetched for SoundCloud.

**Playing.** Three shapes — immersive portrait, landscape with full controls,
and an audio mode with artwork — plus an in-player queue, autoplay, repeat one
or all, shuffle, a playback speed that is remembered, resume from where you
stopped, and the screen kept awake. Audio keeps playing in the background with
a media notification and lock-screen controls, a mini player sits above the
main screens, and leaving the video player offers to continue the same item as
audio **from the same second**.

**Shorts.** Any portrait clip of three minutes or less opens in a swipeable
full-screen lane that skips over everything that is not a short, with a tap to
pause, a double tap to favourite, and its own chip in the library.

**Favourites and playlists.** A heart on every card; playlists you create,
reorder by dragging, play in order or shuffled; and smart playlists that keep
themselves — favourites, latest additions, and (in Super) everything available
offline.

**Settings and safety.** Default quality, theme (system, light or dark), and
language — Arabic or English, matched to the phone on first launch. Backups
are plain text holding no secret, written by themselves after every change,
keeping the last seven by date, restorable by picking a date, and exportable;
the three older encrypted formats can still be read. A diagnostic log viewer
can be shared only after URLs, IP addresses, credentials and storage paths are
stripped out.

**Updating itself.** Each app checks this repository for its own newer
release, downloads the APK, and hands it to the system installer. Nothing
installs without your confirmation, and a version can be skipped.

### MeTube Lite only

- **Pulls the file to the phone and then deletes it from the server**, so a
  server shared with family and friends does not fill up.
- **An optional Wi-Fi-only rule** — off unless you turn it on — that holds
  transfers back on mobile data; the tasks wait and resume by themselves.
- A library built by scanning the app's own download folder, with a platform
  filter and live counts.
- Finished files are registered with Android so they appear in the phone's
  gallery.

### MeTube Super only

- **Keeps the file on the server** and merges `/history` with the local index
  into one library keyed by canonical URL, with filters for everything,
  what is offline, and what is only on the server.
- **Streams from the server** with authentication, and always prefers a local
  copy when one exists — the resume position is shared between the two.
- **Tags** you create and attach to anything, as chips in the library and a
  screen to rename or delete them.
- **Make available offline**: keep a local copy while the original stays on
  the server; remove just the local copy; share the local file if there is one
  and download-then-share if there is not.
- Batch operations, including tagging many items at once.
- **A local address and external ones**, tried again on every network change
  so the phone uses the fast path at home and the tunnel elsewhere, with a
  live status dot for each and a server card in settings.

## Screenshots

| MeTube Lite | MeTube Super |
|---|---|
| ![Lite, day](docs/screenshots/lite-day.png) | ![Super, day](docs/screenshots/super-day.png) |
| ![Lite, night](docs/screenshots/lite-night.png) | ![Super, night](docs/screenshots/super-night.png) |

The library shown is invented for these screenshots — the titles, the channels
and the covers are all generated, and no real server or account appears in
them.

## Download

Signed APKs are published on the
[releases page](https://github.com/sagheerys/metube-mobile/releases), one per
app. Android will ask you to allow installing from this source the first time;
that permission is per application, and you can withdraw it afterwards.

The current release is **[v2.0.0](https://github.com/sagheerys/metube-mobile/releases/latest)**:
`MeTube-Lite-2.0.0.apk` for family and friends, `MeTube-Super-2.0.0.apk` for the
server owner's. They are separate apps and install side by side. From this
release on, each app checks for its own successor and can install it for you.

Both apps can update themselves: **Settings → About → check for updates**
fetches the newest release and hands the APK to the system installer. Nothing
is installed without you confirming it.

Or build from source, below.

## Requirements

- A reachable MeTube server (this is a client — it downloads nothing by itself).
  Four of its settings change how the apps behave; see
  **[docs/SERVER-SETUP.md](docs/SERVER-SETUP.md)**.
- Android. `compileSdk 37`; the minimum SDK follows the Flutter toolchain default.
- Flutter **3.47.2** (Dart SDK `^3.13.0`) to build from source.

## Getting started

```bash
git clone https://github.com/sagheerys/metube-mobile.git
cd metube-mobile
flutter pub get

# debug
cd apps/metube_super && flutter run        # or apps/metube_lite

# release
cd apps/metube_super && flutter build apk --release
```

Release builds are signed from `apps/<app>/android/key.properties`, which is
**not** in this repository. Create your own keystore, or build debug.

On first launch, open **Settings** and enter your server URL (plus username and
password if your server is behind basic auth).

## Layout

```
packages/mt_core     pure Dart: MeTube API client, download engine, storage,
                     backup, logging — no Flutter imports
packages/mt_media    playback: audio_service handler, playback sources, position
                     and state stores, mini player
packages/mt_ui       the "Wahaj" design system: tokens, themes, shared widgets,
                     localization (ar/en)
apps/metube_lite     the edition for family and friends
apps/metube_super    the server-owner edition
docs/                the repository map, the server contract and the server setup
```

Dependency direction is one-way: `apps → mt_media → mt_core`. `mt_ui` knows
nothing about the server, and `mt_core` contains no Flutter code.

## Tests

```bash
cd packages/mt_core  && dart test              # 362
cd packages/mt_media && flutter test           # 115
cd packages/mt_ui    && flutter test           #  44
cd apps/metube_lite  && flutter test           #  69
cd apps/metube_super && flutter test           # 121
```

**712 tests** at the time of writing, and `flutter analyze` is expected to be
clean. Fixtures come from real server JSON, and every fixed defect leaves behind
a test that fails on the old code.

## Translations

The UI has no hardcoded strings: everything lives in
`packages/mt_ui/lib/src/l10n/app_en.arb` and `app_ar.arb`.

Adding a language is two steps — a new `app_<code>.arb` next to those, and one
line in `packages/mt_ui/lib/src/l10n/language_names.dart` giving the language's
name **in its own language**. The settings screen builds its list from
`supportedLocales`, so a new language appears by itself. Run
`cd packages/mt_ui && flutter gen-l10n` afterwards.

Translations are very welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## Documentation

| | |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | The map of the repository: the packages, the rules that hold them together, where a feature belongs, how to run the tests. English first, with an Arabic version below it. |
| [docs/SERVER-API.md](docs/SERVER-API.md) | The contract with the MeTube server: every request and response, the local storage schema, and the traps that each cost a debugging session. Read it before touching networking or storage code. |
| [docs/SERVER-SETUP.md](docs/SERVER-SETUP.md) | How to configure the server, the four settings whose absence looks like an app defect, and how to reach it safely from outside. |
| [CONTRIBUTING.md](CONTRIBUTING.md) | What a change has to satisfy before it lands. |
| [CHANGELOG.md](CHANGELOG.md) | What changed, release by release. |
| [SECURITY.md](SECURITY.md) | Reporting a vulnerability. |

The project's working language is Arabic; the documents are written in English,
and issues and pull requests are welcome in either language.

## Credits

- [MeTube](https://github.com/alexta69/metube) by alexta69 — the server these
  apps are clients for (AGPL-3.0).
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) — what MeTube uses to do the actual
  downloading (Unlicense).
- The Flutter and Dart teams, and the authors of the packages listed in each
  `pubspec.yaml`.

## License

[GPL-3.0](LICENSE) — Copyright (C) 2026 Yasir Sagheer.

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version. It is distributed **without any warranty**; see the license for
details.
