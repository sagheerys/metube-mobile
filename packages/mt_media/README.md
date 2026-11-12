# mt_media

Shared playback: the `audio_service` handler, video playback, playback sources,
position and state stores, and the mini player. It knows the server only
through `mt_core`.

`package:mt_media/library.dart` is a second entry: the merged library that
Super and Ember share. It stays out of `mt_media.dart` because Lite has its own
library types with the same names.

```bash
flutter test --no-pub
```

See [docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md) for how the pieces fit.
