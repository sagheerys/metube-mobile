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
| From outside: "not a MeTube server"; at home it connects | a login page in front of the API (Cloudflare Access) — use basic auth, or a Bypass policy for that hostname |
| The password is right and the app still says wrong credentials | a non-ASCII password hashed with `btoa()` in a Worker — encode it as UTF-8 (see above) or keep the password ASCII |
| Works at home, works away, but is far slower away | fill in `local_url` too, in Super's **Settings → Network** |

The full request-and-response contract, and the traps that were measured
rather than assumed, are in [SERVER-API.md](SERVER-API.md).
