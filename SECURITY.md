# Security

## Reporting a vulnerability

**Do not open a public issue for a security problem.**

Use GitHub's private reporting instead: go to the repository's **Security** tab
and choose **Report a vulnerability**. That opens a thread only you and the
maintainer can read, and it stays private until a fix exists.

Please include what you did, what happened, and the version from
**Settings → About**. A proof of concept is welcome and never required.

You should get a first reply within a week. If a report turns out to be real, a
fixed release follows, and you are credited in the release notes unless you
would rather not be.

## What is in scope

These are client apps for a server you run yourself. The interesting surface is
small and worth naming:

- **The server contract.** The apps send `Authorization: Basic` on every
  request, including streaming. Anything that leaks those credentials — into a
  log, a backup, a crash report, an intent, a URL — is a real issue.
- **The path guard.** Server filenames are checked in
  `MeTubeApiClient.downloadUrl()` before a URL is ever built from them. A name
  that escapes it and reaches the filesystem or a media player is a real issue.
- **The backup file.** It is deliberately plain text and deliberately holds no
  secret: no password, no username, and credentials embedded in a URL are
  stripped. A secret found inside one is a real issue.
- **The self-update path.** The downloaded APK is checked for the ZIP magic
  bytes and for the size the release announced, then handed to the system
  installer as a `content://` URI. Anything that gets a different file
  installed is a real issue.
- **The diagnostic log.** It is scrubbed before it can be shared, of
  credentials, URLs, paths and addresses. A secret surviving the scrub is a
  real issue.

## What is out of scope

- **The MeTube server itself.** Report those to
  [alexta69/metube](https://github.com/alexta69/metube).
- **yt-dlp**, and the sites it downloads from.
- **A server exposed without authentication.** These apps cannot protect a
  server anyone can reach; see [docs/SERVER-SETUP.md](docs/SERVER-SETUP.md).
- **An attacker who already has your unlocked phone.** Android's own protection
  is the boundary; the apps do not add one.

## Supported versions

The newest release is the one that gets fixes. This is a small project, so
older versions are not maintained in parallel.
