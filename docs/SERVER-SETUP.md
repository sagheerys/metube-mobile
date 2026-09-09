# Setting up the server

These apps are clients. They download nothing themselves: every file is
fetched by a [MeTube](https://github.com/alexta69/metube) server you run, and
the apps only ask it to work and then read the result.

**Four things the apps depend on are server settings, not app settings.** Each
one, when missing, produces a symptom in the app that looks like an app defect
and is not. This page is the list.

---

## A working starting point

```yaml
# docker-compose.yml
services:
  metube:
    image: ghcr.io/alexta69/metube
    container_name: metube
    restart: unless-stopped
    ports:
      - "8081:8081"
    volumes:
      - /path/on/your/disk/downloads:/downloads
    environment:
      # Deleting an item really removes the file. See below — this one
      # matters most.
      DELETE_FILE_ON_TRASHCAN: "true"

      # Put the source id into the filename, so two clips that share a
      # title do not collide.
      YTDL_OPTIONS: '{"outtmpl":"/downloads/%(title)s.%(id)s.%(ext)s"}'

      # Serve the files back over HTTP so the apps can pull and stream them.
      DOWNLOAD_DIRS_INDEXABLE: "true"

      # Let the apps ask for an H.264 build by name. See below. A folded
      # block keeps YAML out of the way of the quotes inside the value.
      YTDL_OPTIONS_PRESETS: >-
        {"compat_h264":{"format":"bestvideo[vcodec~='^(h264|avc)'][ext=mp4]+bestaudio[ext=m4a]/best[ext=mp4]/best"}}

      # Only if a platform you use demands a signed-in session.
      # COOKIES_FILE: /downloads/cookies.txt
```

Then, in the app: **Settings → the server URL**, plus a username and password
if the server sits behind basic auth.

---

## The four settings, and what happens without each

### `DELETE_FILE_ON_TRASHCAN=true`

**Without it, Lite quietly fills your disk.**

Lite's whole purpose is to pull a file to the phone and then clean the server.
It does that by calling `POST /delete`. With this setting off, MeTube removes
the **history row** and leaves the file on disk. The app reports success
truthfully — the server did what it was asked — and the download folder grows
without limit, with nothing in any interface to show it.

Super does not delete by default, so it is unaffected.

### `YTDL_OPTIONS` with an id in `outtmpl`

**Without it, two clips that share a title overwrite each other.**

The default template is the title alone. Two videos called "Trailer" become
one file. Putting `%(id)s` into the name makes every download distinct, and
it is what the apps' own filename handling was measured against.

### `DOWNLOAD_DIRS_INDEXABLE=true`

**Without it, nothing plays and nothing pulls.**

Both apps fetch files over `GET /download/<filename>`. Super also streams from
that same URL. If the server does not serve the download directory, adding a
link still works and everything after it fails.

### `YTDL_OPTIONS_PRESETS` with `compat_h264`

**Without it, Facebook clips look smeared on most phones.**

Facebook publishes its separated formats as AV1 only. MeTube's format chain
has three steps, and the middle one carries no codec filter, so it grabs an
AV1 file before the chain can reach the H.264 one that is actually available.
Hardware AV1 decoding is absent from most phones, so a software decoder takes
over, falls behind, and the picture tears.

The apps cannot fix this from their side: the format string is built on the
server. What they do instead is send **the name of a preset** — never a
free-form yt-dlp option, so `ALLOW_YTDL_OPTIONS_OVERRIDES` stays off and no
client can hand your server arbitrary options.

A server that does not know the name answers 400, and the app quietly retries
without it. So this is optional: you lose the fix, not the download.

### `COOKIES_FILE`

Only needed for platforms that refuse anonymous access. When a download fails
with a message about signing in, a cookie or a bot check, the apps classify it
and say so rather than showing a generic failure — but the cure is on the
server.

---

## Reaching it from a phone

- **On your own network**, plain HTTP is fine. Lite restricts cleartext to
  private addresses, so add your server's address to
  `apps/metube_lite/android/app/src/main/res/xml/network_security_config.xml`
  if you build Lite yourself. Super allows cleartext broadly.
- **From outside**, put it behind HTTPS. Anything that terminates TLS works —
  a reverse proxy, or a tunnel. Add basic auth while you are there: the apps
  send `Authorization: Basic` on every request, including the streaming ones.
- **Never expose a MeTube server without authentication.** Anyone who finds it
  can queue downloads onto your disk and read everything already there.

## Checking it before you blame the app

```bash
curl -u user:pass 'https://your-server/history?limit=1'
```

A healthy server answers HTTP 200 with JSON carrying **both** `done` and
`queue`. That exact response is what the apps use to decide a URL is a MeTube
server at all:

| What you get | What the app will say |
|---|---|
| 200 with `done` and `queue` | connected |
| 200 with HTML | not a MeTube server |
| 401 | wrong credentials |
| 404 | there is no MeTube API here |
| nothing, or a timeout | unreachable |

## Symptoms, and the setting behind each

| What you see | What to set |
|---|---|
| Lite says the server was cleaned, but the disk keeps filling | `DELETE_FILE_ON_TRASHCAN=true` |
| Facebook clips play torn or smeared | `YTDL_OPTIONS_PRESETS` with `compat_h264` |
| Downloads complete on the server but the app cannot pull them | `DOWNLOAD_DIRS_INDEXABLE=true` |
| Two clips with the same title become one file | `%(id)s` in `YTDL_OPTIONS` `outtmpl` |
| One platform always fails with a sign-in message | `COOKIES_FILE` |
| Streaming fails in Super while downloading works | HTTPS, or cleartext allowed for that host |

The full request-and-response contract, and the traps that were measured
rather than assumed, are in [SERVER-API.md](SERVER-API.md).
