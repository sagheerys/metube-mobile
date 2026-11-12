# mt_ui

The Wahaj design system: tokens, the four palettes (day and night for Lite and
for Super), themes, shared widgets, icons and the translations (`lib/src/l10n`).
It knows nothing about the server.

After editing an `.arb` file:

```bash
flutter gen-l10n
flutter test --no-pub
```

See [docs/ARCHITECTURE.md](../../docs/ARCHITECTURE.md) for how the pieces fit.
