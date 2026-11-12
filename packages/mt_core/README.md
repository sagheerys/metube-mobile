# mt_core

The core shared by the three apps: the MeTube API client (the only place that
talks to the server), models, the download engine, storage, backups, logging
and URL tools.

**Pure Dart, no Flutter import**, so it is tested with `dart test`:

```bash
dart test
```

The server contract it implements is [docs/SERVER-API.md](../../docs/SERVER-API.md).
See [docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md) for how the pieces fit.
