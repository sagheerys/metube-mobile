# MeTube Lite

The family edition, for Android. Each download is pulled to the phone, then
deleted from the server, so the server cleans itself up. Plays local files only.

Built on `mt_core`, `mt_media` and `mt_ui`; it does not use `mt_transcripts`.

```bash
flutter test --no-pub
flutter build apk --debug
```

See [docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md) for how the pieces fit. Releases and screenshots are in the [main README](../../README.md).
