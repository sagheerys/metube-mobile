# mt_transcripts

Transcripts for the server owner's apps (Super and Ember): subtitle parsing,
chapters, Arabic-aware search, the transcript store, and fetching subtitles from
MeTube without touching the library. Lite does not depend on it.

**Pure Dart, no Flutter import**, so it is tested with `dart test`:

```bash
dart test
```

`bin/backfill.dart` fetches transcripts for clips downloaded earlier; see
[docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md) §5.
