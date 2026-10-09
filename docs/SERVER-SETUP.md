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
if the server sits behind basic auth. To put a password on it at home and
over Tailscale as well, see
[Locking your home network and Tailscale too](#locking-your-home-network-and-tailscale-too).

---

## One server, or two?

**Recommended: one server for Lite, another for Super.**

The two apps treat the same server in opposite ways. Lite deletes each file
from the server once the phone has it; Super keeps everything. Sharing one
instance puts those two habits in the same place, and they collide in three:

- **A link you both want.** MeTube's history holds one entry per URL. Lite
  deletes only the link it pulled — but if that link is one you were keeping
  for Super, the entry it removes is yours.
- **`DELETE_FILE_ON_TRASHCAN` is server-wide.** One instance cannot erase the
  family's files and at the same time leave yours removable but on disk.
- **The history is shared.** MeTube has no accounts: whoever opens the web UI
  sees what everyone else downloaded.

Two containers from the same image cost almost nothing — a second port and a
second download folder:

```yaml
services:
  metube-family:              # MeTube Lite points here
    image: ghcr.io/alexta69/metube
    container_name: metube-family
    restart: unless-stopped
    ports:
      - "8081:8081"
    volumes:
      - /path/on/your/disk/family:/downloads
    environment:
      DELETE_FILE_ON_TRASHCAN: "true"
      # …the rest of the environment above, unchanged.

  metube-archive:             # MeTube Super points here
    image: ghcr.io/alexta69/metube
    container_name: metube-archive
    restart: unless-stopped
    ports:
      - "8082:8081"
    volumes:
      - /path/on/your/disk/archive:/downloads
    environment:
      DELETE_FILE_ON_TRASHCAN: "true"
      # …the rest of the environment above, unchanged.
```

**One server is fine** if you are its only user, or if nobody with Lite ever
asks for a link you keep. This is a recommendation, not a requirement: start
with one if that is simpler, and split them the day the two habits get in each
other's way.

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

### Optional: `YTDL_OPTIONS` with subtitles, for Super's search inside clips

**Without it, Super has transcripts only for the clips added from the app.**

Super's "Search inside clips" (Settings → Transcripts) fetches a YouTube
clip's subtitles through the server before the clip itself is added. It
cannot do that afterwards: MeTube keeps one record per URL, and asking for an
existing clip's subtitles replaces the clip's own record. So what a
subscription brings, what the web page or a batch downloads, has no
transcript.

The way around it is to have the server write the subtitles **beside every
file it downloads**, and let Super read them from there. Extend the
`YTDL_OPTIONS` line (keep your own `outtmpl`):

```yaml
      YTDL_OPTIONS: >-
        {"outtmpl":"/downloads/%(title)s.%(id)s.%(ext)s",
         "writesubtitles":true,"writeautomaticsub":true,
         "subtitleslangs":["ar(-(?![a-z][a-z][a-z]?(-|$)).*)?","ar-ar-.*",
                           "en(-(?![a-z][a-z][a-z]?(-|$)).*)?","en-en-.*"],
         "subtitlesformat":"vtt/srt/best","ignoreerrors":true}
```

On TrueNAS, or any panel with one field per environment variable, the name
is `YTDL_OPTIONS` and the value is the same, on one line:

```
{"outtmpl":"/downloads/%(title)s.%(id)s.%(ext)s","writesubtitles":true,"writeautomaticsub":true,"subtitleslangs":["ar(-(?![a-z][a-z][a-z]?(-|$)).*)?","ar-ar-.*","en(-(?![a-z][a-z][a-z]?(-|$)).*)?","en-en-.*"],"subtitlesformat":"vtt/srt/best","ignoreerrors":true}
```

**Which languages.** Super reads the app's language and English, nothing
else, so the server needs to write those two. Keep the `ar` pair for an
Arabic interface; with the app in English, the `en` pair alone is enough.
Another code costs the server requests and is never read.

**Why the patterns look this way.** YouTube no longer names every track by
its language alone. On a clip with several audio tracks (music videos from
the big labels, dubbed films) the tracks carry a suffix: `en-nP7-2PuUl7o` is
the English subtitles, `en-en-nP7-2PuUl7o` the English automatic captions,
`ar-en-nP7-2PuUl7o` a machine translation into Arabic. Each pair takes a
language's own tracks, plain or suffixed, and leaves the suffixed
translations out. A plain `ar` on an English clip is itself YouTube's machine
translation: it is fetched when YouTube allows it and sometimes refused with
a 429, and the clip downloads either way. So an English clip gives English,
and usually Arabic as well; an Arabic clip gives Arabic and English.

**How to check it works.** Download one YouTube clip from MeTube's web page.
Beside its file a subtitle appears under the same name, with `.en.vtt` (or
`.ar.vtt`) in place of the extension: `Me at the zoo.jNQXAC9IVRw.en.vtt`
beside `Me at the zoo.jNQXAC9IVRw.webm` with the template above. You can see
it in the download folder, or at `http://your-server:8081/download/`. Then,
in Super, turn on Settings → Transcripts → "Search inside clips", pull the
library down to refresh, and within a minute search for a word said in the
clip.

Before adding it, know these:

- **`ignoreerrors` must stay `true`.** Without it, a subtitle that YouTube
  refuses (a 429) fails the **whole download**, with no video. With it, the
  refusal is a warning and the video arrives; a download that really fails
  is still reported as failed. The option applies to every job the server
  runs, not only to subtitles: inside a playlist or channel, an entry that
  fails may be skipped with a warning rather than stopping the rest.
- **Subtitles add requests to YouTube.** Each clip now asks for its
  subtitles too, and a server that YouTube already rate-limits may meet 429s
  sooner, on subtitles first.
- **`DOWNLOAD_DIRS_INDEXABLE=true` is needed** (it is above, for other
  reasons too). Super reads the folder's index to find the suffixed tracks;
  without it, only the plain names (`.en.vtt`) are tried.
- **The subtitle file outlives its clip.** MeTube deletes the clip's own file
  on a trashcan delete and leaves the subtitle beside it, a few kilobytes
  each.
- **It covers new downloads only.** Clips downloaded before the line was
  added have no file to read. For those there is a tool for a computer,
  `packages/mt_transcripts/bin/backfill.dart`: it needs a clone of this
  repository, the Dart SDK, yt-dlp (with `curl_cffi`) and ffmpeg, reads the
  server's list, fetches the subtitles on the computer, and writes one file
  that Super imports from Settings → Transcripts → Import. Running it with no
  arguments prints its usage.

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

---

## Closing the server off from the outside

MeTube has no login of its own. Whatever you put in front of it *is* the
authentication. This section is what the apps were built and measured
against.

### Cloudflare Tunnel

A tunnel is the option that opens no port at all: `cloudflared` dials out
from your network and Cloudflare hands traffic back down that connection,
so the server keeps every inbound port closed and TLS is terminated for
you.

```yaml
  # alongside the metube service above
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared
    restart: unless-stopped
    command: tunnel run
    environment:
      TUNNEL_TOKEN: "paste the token from the Zero Trust dashboard"
```

Point the tunnel's public hostname at `http://metube:8081`, and put that
hostname in the app as the server URL.

**A tunnel is reach, not protection.** On its own it publishes MeTube to
anyone who learns the hostname. Add one of the two below.

### The way that works: basic auth in front of MeTube

The apps carry a username and password on **every** request — the API
calls, the file pulls, and the streaming requests the players make — so
anything that checks `Authorization: Basic` protects the whole server
without breaking either app. Two places to put that check.

**A Cloudflare Worker on the hostname.** Nothing to install beside the
tunnel, and the request is rejected at the edge before it ever travels
down it:

```js
export default {
  async fetch(request) {
    const USERNAME = "family";
    const PASSWORD = "put a real one here";

    // The apps base64 the credentials as UTF-8. Plain btoa() is Latin-1:
    // it throws outright on Arabic, and silently produces a different
    // string for accented Latin, which reads as a wrong password forever.
    const expected = "Basic " + btoa(
      String.fromCharCode(...new TextEncoder().encode(`${USERNAME}:${PASSWORD}`)),
    );
    const got = request.headers.get("Authorization") ?? "";

    // Compare every character rather than bailing at the first mismatch.
    let diff = got.length ^ expected.length;
    for (let i = 0; i < got.length; i++) {
      diff |= got.charCodeAt(i) ^ expected.charCodeAt(i % expected.length);
    }
    if (diff !== 0) {
      return new Response("Unauthorized", {
        status: 401,
        headers: { "WWW-Authenticate": 'Basic realm="MeTube"' },
      });
    }

    return fetch(request);
  },
};
```

Bind it to **`metube.example.com/*`** — with the trailing `/*`. A route
without it covers the root and nothing else, so `/history` and
`/download/...` stay open to anyone: the whole library, reachable, while
the front page asks politely for a password.

**Or a reverse proxy at the origin**, if you would rather keep the check
on your own hardware. With Caddy that is four lines:

```
metube.example.com {
    basic_auth {
        yasir $2a$14$...      # caddy hash-password
    }
    reverse_proxy metube:8081
}
```

Either way, prove it before you trust it — no credentials, and the answer
must be 401:

```bash
curl -si https://metube.example.com/history | head -1
curl -si https://metube.example.com/download/ | head -1
```

A 401 is also the one failure the apps name exactly: they report wrong
credentials rather than a generic error.

Turn on **Always Use HTTPS** for the hostname while you are in the
dashboard. Basic auth is a password in a header: over plain HTTP it
travels in the clear, and a first request that arrives as `http://` has
already sent it before any redirect can help. Lite refuses cleartext to a
public address on its own, so the app side is covered; a browser is not.

### Locking your home network and Tailscale too

A lock on the public hostname leaves MeTube's own port open on your network:
anyone on your Wi-Fi, or any device in your tailnet, reaches it at
`http://server-ip:8081` without a password, around the lock. To close every
road, put the proxy in front of **all** of them and do not publish MeTube's
port at all. This is the setup MeTube's own wiki points to
([reverse proxy configurations](https://github.com/alexta69/metube/wiki/Reverse-proxy-configurations)):
basic auth in the proxy, MeTube behind it.

```yaml
# docker-compose.yml
services:
  metube:
    image: ghcr.io/alexta69/metube
    restart: unless-stopped
    # No "ports:" on purpose: only Caddy can reach MeTube.
    volumes:
      - /path/on/your/disk/downloads:/downloads
    environment:
      DELETE_FILE_ON_TRASHCAN: "true"
      DOWNLOAD_DIRS_INDEXABLE: "true"
      # ...the rest of your settings from the starting point above

  caddy:
    image: caddy:latest
    restart: unless-stopped
    ports:
      - "8081:8081"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
```

```
# Caddyfile
:8081 {
	basic_auth {
		family $2a$14$...
	}
	reverse_proxy metube:8081
}
```

The hash comes from Caddy itself:
`docker compose exec caddy caddy hash-password --plaintext 'your password'`.

In the app nothing changes but the two credential fields: the server URL is
still `http://server-ip:8081`, and a Tailscale address such as
`http://100.x.y.z:8081` reaches the same Caddy and the same lock. A tunnel
running in the same file points at `http://caddy:8081` instead of
`http://metube:8081`.

**One username and one password for every lock.** The apps keep a single
pair and send it to every address they know: Super's local URL and each of
its external URLs alike. If the tunnel passes a Worker and then this Caddy,
the one `Authorization` header has to satisfy both, so two different
passwords mean the external address answers 401 for good, and so does a
Worker that drops the header before forwarding. The simplest arrangement is
one lock: point the tunnel at Caddy and leave the Worker out.

Check it from another machine on your network:

```bash
curl -si http://server-ip:8081/history | head -1                 # 401
curl -si -u family:password http://server-ip:8081/history | head -1   # 200
```

Measured on 2026-10-08 against a real server on TrueNAS with Caddy in front:
Super connected, listed the library and streamed over the home network and
over Tailscale with the password, and both addresses answered 401 without
it. Over plain HTTP at home the password crosses your own network in the
clear; over Tailscale the traffic is already encrypted.

### The way that does not work: Cloudflare Access

Cloudflare Access (Zero Trust policies, the e-mail/OTP login page) cannot
be used in front of MeTube while these apps are the client, and the failure
is quiet rather than loud:

- Access answers an unauthenticated request with a redirect to a browser
  login page. The apps follow it, receive HTML with a 200, and report
  **"not a MeTube server"** — the same message a wrong URL produces.
- Access **service tokens** would be the headless answer, but they are sent
  as `CF-Access-Client-Id` and `CF-Access-Client-Secret` headers. The apps
  send `Authorization: Basic` and nothing else; there is no field for a
  custom header anywhere in either app.

If you already run Access over your domain, add a **Bypass** policy for the
MeTube hostname and let basic auth do the work there instead.

### Two URLs, because a tunnel is slow at home

Measured on 2026-09-01 with the phone standing next to the server: 2MB
took **2.3s** over the local address and **94.8s** through the tunnel —
**41x**, for traffic that never needed to leave the house.

So Super holds two addresses: the external one (your tunnel hostname) and
`local_url` (the address on your own network). It probes and adopts
whichever answers, on a network change, on returning to the foreground, and
at startup. Fill both in **Settings → Network** and the switch stops being
something you think about.

Lite keeps a single URL by design: put the tunnel hostname there, and it
works from anywhere at the tunnel's speed.

### Two cautions about Cloudflare specifically

- Cloudflare's terms restrict serving a large volume of video through the
  proxy on the free plan. A family streaming its own library is not what
  that rule is aimed at, but a public library on a free domain is a real
  risk of being asked to stop.
- The proxy caps a **request** body at 100MB on the free plan. It never
  applies here — the apps send URLs, not files — and responses, which is
  what a download is, are not capped.

- A Worker on the free plan is allowed 100,000 requests a day, and the
  apps poll while work is in flight: `/history` every 5s per running task,
  plus every 2s while the library screen is showing one (both timers stop
  when nothing is active — an idle app is silent). That is roughly 400
  requests for a ten-minute download watched on screen, so the ceiling is
  around two hundred such downloads in a day. Worth knowing, not worth
  worrying about.

### If you would rather nothing were public at all

A private mesh — Tailscale, WireGuard, or your router's own VPN — leaves
MeTube reachable only by your own devices, with no hostname to find and no
login page to protect. The apps do not care: give them the mesh address as
the server URL, and Super can hold that as its external URL with the LAN
address as `local_url`.

A Tailscale address (`100.x.y.z`) is not an internet address. Only devices
signed in to **your** tailnet can reach it; someone who learns it and runs
Tailscale on their own account lands in their own tailnet, not yours. So
Tailscale on its own is safe without a password. The lock above adds what
Tailscale does not cover: guests on your home Wi-Fi, and a device of yours
that ends up in someone else's hands.

You can also keep both roads: Super holds a tunnel hostname and a Tailscale
address side by side under **Settings → Network**, and adopts whichever
answers, so a slow or unreachable tunnel falls back to Tailscale on its own.
With one lock and one password, both work the same way. The phone needs
Tailscale switched on for that address, and Android runs one VPN at a time.

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
| Super's search inside clips finds nothing in what subscriptions bring | `writesubtitles` and friends in `YTDL_OPTIONS` (optional, above) |
| Streaming fails in Super while downloading works | HTTPS, or cleartext allowed for that host |
| From outside: "not a MeTube server"; at home it connects | a login page in front of the API (Cloudflare Access) — use basic auth, or a Bypass policy for that hostname |
| The password is right and the app still says wrong credentials | a non-ASCII password hashed with `btoa()` in a Worker — encode it as UTF-8 (see above) or keep the password ASCII |
| Works at home, works away, but is far slower away | fill in `local_url` too, in Super's **Settings → Network** |

The full request-and-response contract, and the traps that were measured
rather than assumed, are in [SERVER-API.md](SERVER-API.md).
