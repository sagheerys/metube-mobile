# MeTube Ember

The server owner's edition for Windows 10 and 11 (x64): Super's library,
streaming, tags, subscriptions, folders and transcripts in a desktop layout,
with a side panel, the keyboard and a floating player window. Playback uses
`media_kit`.

Built on `mt_core`, `mt_media`, `mt_ui` and `mt_transcripts`.
Everything specific to Windows lives in `lib/platform/`.

```bash
flutter test --no-pub
flutter build windows --debug
flutter test integration_test -d windows   # the real player engine
```

See [docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md) for how the pieces fit. Releases and screenshots are in the [main README](../../README.md).
