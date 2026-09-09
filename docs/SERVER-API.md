# The server contract and the local data schema

**There is no backend of our own.** The "backend" is a stock
[MeTube](https://github.com/alexta69/metube) server (yt-dlp behind a small web
UI), and everything the apps keep locally is a set of indexed key-value stores.

This document is the authority on every request and response (§1–§4), on the
local storage schema (§5), and on the traps that are written down here because
each one cost a real debugging session (§6). **Network and storage code is
written from this file, not from guesswork.**

It was extracted from the *behaviour* of a running server rather than from
documentation: the previous generation of these apps shipped docs that were
wrong in places (one claimed an `/api` prefix that does not exist).

---

## 1. Talking to the server

- **Transport.** HTTP/HTTPS through Dio. **No WebSocket** — the server offers
  Socket.IO, but both apps poll deliberately, and that stays.
- **Authentication.** HTTP Basic on every request:
  `Authorization: Basic base64(user:pass)`, applied by a single interceptor.
- **Base URL.** Entered by the user with no prefix
  (`https://metube.example.com`); a trailing slash is stripped.
- **Timeouts.** 30s connect · 30min receive (pulls only) · 10s connection test ·
  4s quick probe — all from `MTConstants`.
- **Parsing.** A response may arrive as text, so it is read with
  `responseType: plain` and decoded defensively. Never pass
  `responseType: bytes` to `dio.download`.

## 2. The four endpoints

### 2.1 Connection test / discovery

```
GET {base}/history?limit=1
```

Valid ⟺ HTTP 200 **and** a JSON map carrying both `done` and `queue`. HTML means
"not a MeTube server"; 401 means bad credentials; 404 means there is no API
here.

### 2.2 Adding

```
POST {base}/add          Content-Type: application/json
{"url": "<the URL after short-link resolution>", "quality": "best|1080|720|480|audio"}

# With "best playback compatibility" (on by default) — video only:
{"url": "…", "quality": "…", "download_type": "video", "format": "mp4", "codec": "h264"}
```

Success is 200. An error arrives in `error` or `msg` (a string or a map).
**Quality rule:** the numeric qualities are **YouTube only**; everything else is
forced to `best`; `audio` works everywhere.

#### Why the three codec fields exist (measured 2026-09-03)

The owner reported "YouTube clips look smeared in the reels player". Measured
against a real server (MeTube 2026.08.28 · yt-dlp 2026.08.19):

| What was sent | What came back |
|---|---|
| `quality:best` alone | `.webm` — **vp9** 480×848 or **av1** 1920×1080 |
| `+ format:mp4` | `.mp4`, but the video is **still av1** — the field changes the container, not the codec |
| `+ format:mp4 + codec:h264` **without** `download_type` | the record comes back with `codec:auto` and the file is **av1** — the field is ignored |
| `+ download_type:video + format:mp4 + codec:h264` | `.mp4` — **h264 Main / aac LC** ✅ |

Hardware AV1 decoding is absent from most phones, so a software decoder takes
over and falls behind the frame rate, which is what "smeared" looks like. The
three fields are part of MeTube's own contract: its web UI sends
`download_type` from `video|audio|captions|thumbnail`, `codec` from
`auto|h264|h265|av1|vp9`, and `format` from `any|mp4|ios|…`.

**Three binding constraints.** (1) Send **all three or none** — any subset is
silently ineffective. (2) **Never send them with `quality:audio`**: `format:mp4`
on an audio-only path changes the container that was asked for. (3) The
`compatible_playback` preference is read **at the moment of adding**, not when
the engine is constructed.

#### `playlist_item_limit` — what the app thinks is a single item stays single

`PlaylistDetector` recognises **YouTube playlists** and **SoundCloud `/sets/`**,
and nothing else. An artist page, an `/albums` URL, a channel or an account
looks like a single clip to the app and is forwarded as-is — and yt-dlp expands
it server-side into **dozens**. Reported by the owner: an album downloaded 20
clips with no selection screen, and one of them was pulled.

**The damage is worse in Lite**, which pulls one and deletes it from the server,
leaving the other nineteen orphaned on the family's server.

So every URL **not detected as a playlist** is sent with:

```json
{"url": "…", "quality": "best", "playlist_item_limit": 1}
```

MeTube translates that into `ytdl_options['playlistend']` (read from `ytdl.py`),
and it was measured on a real server: a 3-track album plus the limit downloaded
**one**. A genuinely single URL is unaffected (it is not a playlist), and the
batch screen is unaffected (it sends each clip under its own URL).

> **Announced behaviour change.** Anyone who deliberately pasted a channel URL
> to download all of it can no longer do that **from the app**; MeTube's own web
> UI remains available for that.

#### `ytdl_options_presets` — what `codec` cannot do (measured 2026-09-08)

`codec:h264` **is not enough for Facebook**, and the reason is inside MeTube's
own format chain (`dl_formats.get_format`): three steps, and **the middle one
carries no codec filter**.

```
1. bestvideo[vcodec~='^(h264|avc)'][ext=mp4] + bestaudio[ext=m4a]
2. bestvideo[ext=mp4] + bestaudio[ext=m4a]      ← no codec filter at all
3. best[ext=mp4]
```

Facebook's separated formats are **all av01**, so (1) fails and **(2)** grabs an
`av1 1440×2560` file — before (3) can reach the `hd` format, which is
**h264 720×1280 + aac and actually present**. Measured with `yt-dlp -F` and
`ffprobe` against the resulting files:

| Source | Today | With step (2) skipped |
|---|---|---|
| Facebook | `av1 1440×2560` ✗ | **`h264 720×1280`** ✅ |
| YouTube | `avc1 1920×1080` | `avc1 1920×1080` — identical |
| Instagram | `avc1 720×1280` | `avc1 720×1280` — identical |

The format string is built on the server, not here, so the cure is a **preset
named `compat_h264`** defined in `YTDL_OPTIONS_PRESETS` on the container, with
the app sending **only its name**. That avoids opening
`ALLOW_YTDL_OPTIONS_OVERRIDES`, which would accept free-form yt-dlp options from
any client.

```json
{"compat_h264": {"format": "bestvideo[vcodec~='^(h264|avc)'][ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"}}
```

**Two constraints.** (1) It is sent **with `quality:best` only** — the selector
is fixed and carries no `[height<=…]`, so with a numeric quality it would
swallow the height cap and hand 1080p to someone who asked for 720p. (2) A
server that does not know the name answers **400**, so the client **retries
without the preset** rather than failing: this app is open source and runs
against containers nobody configured. Configured preset names can be read from
`GET /presets`.

### 2.3 History (polling)

```
GET {base}/history
→ {"done": [...], "queue": [...], "pending": [...]}
```

**Rhythm.** The download pipeline polls every **5s, capped at 120 times (10
minutes)**. Super's live library refresh runs at **2s** and only while something
is active — with no activity the timer stops.

**Item shape — the tolerant parse** (implemented in `HistoryItem.fromJson` and
tested against real captures):

| Field | Sources, in order | Notes |
|---|---|---|
| `url` | `url` | **The primary key, the canonical URL.** The server canonicalises `youtu.be/X` → `youtube.com/watch?v=X` |
| `id` | `id` ‖ `_id` ‖ (a local uuid) | Not used for deletion — deletion goes by URL |
| title | `title` ‖ `name` | |
| filename | `filename` ‖ `file` | **Never invented from the title** when absent (that used to produce 404s) — wait, or fail clearly |
| uploader | `uploader` ‖ `channel` ‖ `creator` ‖ `artist` ‖ `uploader_id` ‖ `channel_id` | A trailing `[videoid]` is stripped |
| thumbnail | `thumbnail` ‖ `thumb` ‖ `thumbnail_url` ‖ `entry.thumbnails.last.url` | Usually absent ⇒ YouTube: `i.ytimg.com/vi/<id11>/hqdefault.jpg` (**YouTube only**); SoundCloud: oEmbed; otherwise `ArtworkIndex` |
| progress | `percent` ‖ `progress` | If > 1 it is a percentage ⇒ ÷100 |
| status | `status` ‖ `state` | active: downloading/pending/running/preparing · done: completed/done/finished · failed: error/failed, or any error text |
| error | `error` ‖ `msg` ‖ `message` | Containing login/sign in/cookie/bot ⇒ `PlatformBlockedException` |
| time | `timestamp` (ms; > 1e13 ⇒ ns) ‖ `datetime` (ISO) | |

**Fuzzy matching** (`UrlKit.urlsMatch`), in order: literal → YouTube id (11
characters) → longest numeric id of ≥10 digits (Facebook/Instagram/TikTok) →
normalisation (dropping the scheme, `www./m./on.`, the query and the trailing
slash) → containment.

### 2.4 Pulling / streaming

```
GET {base}/download/{Uri.encodeComponent(serverFilename)}
Headers: Authorization: Basic …, Connection: keep-alive
```

- **A mandatory guard**, inside `MeTubeApiClient.downloadUrl()` itself: reject an
  empty name, a name containing a path separator (`/` or `\`) or a NUL
  character, or a name that is exactly `.` or `..`.
  - **Correction 2026-09-03, from a field report.** The condition used to be
    "contains `..`", which rejected every name with consecutive dots. yt-dlp
    truncates long titles with "..." — so clips from X/Twitter and elsewhere
    **failed with "unsafe filename"**. Measured against a real server, a name of
    the shape `…text.  more... [2077436096300945409].mp4` returns
    **HTTP 206 · video/mp4**. Traversal requires a path separator, which is
    rejected, so the narrower condition keeps the same protection without
    rejecting legitimate names.
- **Lite** streams to `Download/MeTube_Lite/<CleanTitle>_<HHmmss>.<ext>` (the
  extension comes from the server's name, defaulting to mp4; the title is cut at
  80 characters).
- **Super** uses the same URL **for streaming** in just_audio / video_player,
  with the auth headers attached.
- Retries: 3 attempts backing off 3s/6s (Cloudflare drops), deleting the partial
  file before each attempt.

### 2.5 Deleting

```
POST {base}/delete       Content-Type: application/json
{"ids": ["<the canonical URL from /history — not the URL the user typed>"], "where": "done"}
```

- **`ids` holds full URLs, not numbers.** Success is 200.
- Removing the file from the server's disk requires `DELETE_FILE_ON_TRASHCAN=true`
  in the container's environment; otherwise only the history row goes.
- Lite deletes automatically after a pull; Super deletes on request
  (`DeletePolicy` in the engine).

## 3. The four-stage download pipeline

```
1) POST /add {url, quality-after-the-platform-rule}
2) Poll /history every 5s (≤120):
     in queue?   ⇒ update progress and status
     in done (fuzzy match)? ⇒ capture filename and canonicalUrl ⇒ 3
     an error state? ⇒ fail immediately with a classified message
                       (no waiting out the 10 minutes — Super used to swallow errors)
3) GET /download/<filename> ⇒ a local file (live progress; cancelling deletes the partial)
4) Per policy: POST /delete with the canonical URL, then index it
   (OfflineIndex / MediaStore)
```

The queue runs at a maximum concurrency of 1 to protect the server, and a single
download takes precedence over batch members.

## 4. External services (outside MeTube's contract, isolated in resolvers)

- **Short links.** `vt./vm.tiktok.com`, `fb.watch`, `facebook.com/share/`,
  `on.soundcloud.com` — redirects are followed, with an **HTTPS→HTTP downgrade
  refused**.
- **SoundCloud.** oEmbed (`soundcloud.com/oembed?format=json&url=…`, upgrading
  `-large.` → `-t500x500.`). For `/sets/` playlists: parse
  `window.__sc_hydration` out of the HTML, falling back to extracting a
  `client_id` (32 characters) from the JS bundles and calling
  `api-v2.soundcloud.com/resolve` and `/tracks?ids=`. **Fragile by nature** —
  when it fails nothing breaks, the URL is passed to the server untouched.
- **YouTube playlists.** `youtube_explode_dart`, plus an `og:image` scrape for
  the playlist cover.

---

## 5. The local storage schema

### 5.1 SharedPreferences (behind `KeyValueStore` + `PrefsMutex`, always)

| Key | Type | Content | App |
|---|---|---|---|
| `server_url` | String | The active server URL | both |
| `local_url` / `external_urls` / `active_url` / `auto_switch_enabled` | String / JSON list / String / bool | Automatic server switching | Super |
| `video_quality` | String | Default quality (one of the valid set) | both |
| `theme_mode` / `app_locale` | String | Theme and language | both |
| `offline_index` | JSON map | canonicalUrl → local path | Super |
| `tags_index` | JSON map | canonicalUrl → [tags] | Super |
| `artwork_index` | JSON map | canonicalUrl → cover URL | both |
| `saved_playlists` | JSON list | Saved playlists; entries are `{canonicalUrl, serverFilename, cachedTitle, cachedThumb}` (Lite's older path-based format is imported) | both |
| `audio_state` / `audio_shuffle` | JSON / bool | The current audio queue, for restoring, plus shuffle | both |
| `library_view_mode` / `video_sort_option` | String / String | View mode (`list`/`compact`/`grid`/`cards`) and sorting. **Replaced** `library_compact_view` and `library_grid_view`: two flags that permitted an impossible "compact and grid" state. The old pair is read once for migration and never written again | both |
| `player_play_mode` (+`_<playlist>`) / `player_playback_speed` | String / double | Play modes and speed | both |
| `playback_pos_<url>` | int | Resume positions (keyed by the original URL) | both |
| `batch_save_to_device` | bool | The batch screen's switch: every member that completes is also pulled to the device as "available offline". The original stays on the server | Super |
| `compatible_playback` | bool | "Best playback compatibility": sends `format:mp4` + `codec:h264` on `/add` for video (§2.2). **Defaults to `true`**, added after the smeared-video report. Turning it off allows the highest resolution at the cost of compatibility | both |
| `update_auto_check` / `update_last_check` / `update_skipped_version` | bool / int / String | Self-update: whether to check automatically (**defaults to `true`**) · the timestamp of the last attempt in milliseconds, written **before** the request so a crash-loop of launches cannot repeat it · the version the user chose to skip (only that one is muted; later ones appear). Kept in a separate `UpdatePrefs` store rather than as fields on `SuperSettings`/`LiteSettings` | both |
| `update_downloaded_version` | String | The version of the `update.apk` sitting in the internal cache. At launch, if the running app's version is ≥ this, **the file is deleted** — otherwise ~40MB stays forever after the first successful update. The comparison is by version rather than by existence, so a download whose owner postponed installing is not wiped | both |

> Old key names are kept wherever possible, which is what makes importing old
> backups feasible.

### 5.2 Secure storage (`SecretStore` = flutter_secure_storage)

`username` · `password` · `backup_aes_key` — **none of them ever enters a backup
or a log** (§5.4). `backup_aes_key` is **a leftover**: since 2026-09-04 it is
never generated, exported or imported; it is read only if an earlier version
left one behind, in order to open an `MTF1` backup **on the same device**.

### 5.3 The filesystem

```
/storage/emulated/0/Download/
├── MeTube_Lite/      ← Lite's media (registered in MediaStore)
│   └── backups/      ← metube_lite_<date>.json — the last 7, rotating
└── MeTube_Super/     ← Super's offline media
    └── backups/      ← metube_super_<date>.json — the last 7, rotating
<app-private>/thumbnails/   ← thumbnail cache (disk) + a synchronous memory
                              cache so the grid draws without flicker
<app-private>/logs/         ← a ring log file (MTLogger)
```

### 5.4 Backups

**The backup always survives, and the file holds no secret.** It used to be
encrypted with a key living in secure storage, which dies with "clear data" or a
reinstall — leaving an **orphaned** backup that could only be opened if the user
had exported the key, which nobody does.

| Format | Structure | Handling |
|---|---|---|
| **Plain (v3)** | Formatted JSON: `app/variant/version/backupDate/prefs` — only the keys in §5.1 | read and write |
| `MTF1` | Header + base64(IV) + base64(AES-256-CBC); its payload includes `username` | **read only**, with the device key if it survives |
| `MTBACKUP1` (old Lite) | The same idea, with an exportable Keystore key | **read only** (migration) |
| `MTSBACKUP1` (old Super) | The same, keyed `MTSKEY1` | **read only** (migration) |

Rules:

- **No secret in the file, ever.** No password (as before) and **no username**
  (new) — a username without a password opens nothing anyway. Credentials
  embedded in URLs are stripped.
- Never `json.decode` a file before checking its header: a known header means
  decrypt, its absence together with a leading `{` means plain, and anything
  else raises `BackupFormatException`.
- Decryption uses standard libraries only. (The lesson from old Super:
  hand-rolled base64/utf8 helpers were broken for non-ASCII.)
- **The idea of a "backup key" was removed from the product**: no export, no
  import, no "save this like a password" warning. With no stored key, reading an
  encrypted file raises `BackupKeyMismatchException` outright rather than
  generating a new key that decrypts nothing.

**Rotation** (`BackupRotation`), in `<app media>/backups/`:

- Every backup gets a dated name, `<prefix>_YYYY-MM-DD_HHmmss.json`, and **the
  last 7** are kept. A fresh name each time makes a file-ownership conflict
  impossible: Android 11+ refuses writes over a file created by a previous
  installation (`errno 13`, seen on a real device).
- **Atomic writes** (`.tmp` then rename), so half a backup never remains.
- **A backup identical to the newest one is not written**, or the seven become
  seven moments.
- Restoring shows the dates and lets the user choose — never a blind restore of
  the newest file.
- **Automatic backups run in both apps** (they used to be Lite's alone). Two
  choke points — `PlaylistsStore.onChanged` and `UrlKeyedIndex.onChanged` —
  request a backup after every write, debounced by 3 seconds.

**Android's own automatic backup** is enabled, but `backup_rules.xml` and
`data_extraction_rules.xml` exclude `FlutterSecureStorage.xml`: its contents are
encrypted with the device's Keystore key, which does not travel with it, so the
new phone used to receive nonsense.

### 5.5 Relations (one key for everything)

```
canonicalUrl (from /history) ─┬─ OfflineIndex  → local path
                              ├─ TagsIndex     → [tags]
                              ├─ ArtworkIndex  → cover
                              ├─ PlaylistEntry (inside saved_playlists)
                              └─ playback position (resume across stream ⇄ local)
```

Any new feature keys its data to this — never to a file path and never to a
title.

---

## 6. Traps, each one measured

1. **Delete by the canonical URL.** MeTube identifies items by their full URL:
   delete with what `/history` returned, not with what the user typed.
2. **The CIDR trap on Android.** `<domain>` in `network_security_config` does not
   support CIDR; it is ignored silently, so Dio works (it bypasses the setting)
   and ExoPlayer fails (streaming spins forever). That is why Super allows
   cleartext broadly and Lite restricts it to private ranges.
3. **Never invent filenames or thumbnail URLs.** A missing filename is not built
   from the title, and `i.ytimg.com` URLs are for YouTube only.
4. **Errors fail fast.** Polling errors are not swallowed until the timeout
   expires.
5. **`audioHandler.stop()`** must clear `mediaItem` and `queue`, or a "ghost mini
   player" remains; its visibility hangs on `mediaItem != null`, not on
   `processingState`.
6. **A reference server for testing.** A MeTube container with
   `COOKIES_FILE=…/cookies.txt`, `DOWNLOAD_DIRS_INDEXABLE=true`,
   `DELETE_FILE_ON_TRASHCAN=true` and
   `YTDL_OPTIONS={"outtmpl":"…/%(title)s.%(id)s.%(ext)s"}`, reached over HTTPS
   with Basic auth. The `outtmpl` matters: it is what puts the id into the
   filename that §2.4 has to survive.
