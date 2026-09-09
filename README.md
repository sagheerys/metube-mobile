# MeTube Mobile

Two Android clients for a self-hosted [MeTube](https://github.com/alexta69/metube)
server, built as one Flutter monorepo.

> **Unofficial.** This project is not affiliated with, endorsed by, or connected
> to the MeTube project or its authors, nor to yt-dlp. It is an independent
> client that talks to a MeTube server over its HTTP API. The name "MeTube" is
> used only to say what these apps connect to.

| | **MeTube Lite** | **MeTube Super** |
|---|---|---|
| Made for | family members who just want the file | the person who runs the server |
| After a download completes | pulls it to the device, then **deletes it from the server** | **keeps it on the server** |
| Library | a scan of the local folder | `/history` + the local index, merged into one list |
| Playback | local files | streaming from the server **and** local files |
| Exclusive | Wi-Fi-only downloads, server cleanup | tags, batch downloads, "make available offline", server switching |

Both apps share the same core, media and design packages, and both ship in
**Arabic and English** with a right-to-left-first layout.

## Screenshots

| MeTube Lite | MeTube Super |
|---|---|
| ![Lite, day](docs/screenshots/lite-day.png) | ![Super, day](docs/screenshots/super-day.png) |
| ![Lite, night](docs/screenshots/lite-night.png) | ![Super, night](docs/screenshots/super-night.png) |

The library shown is invented for these screenshots — the titles, the channels
and the covers are all generated, and no real server or account appears in
them.

## Requirements

- A reachable MeTube server (this is a client — it downloads nothing by itself).
- Android. `compileSdk 37`; the minimum SDK follows the Flutter toolchain default.
- Flutter **3.47.2** (Dart SDK `^3.13.0`) to build from source.

## Getting started

```bash
git clone https://github.com/sagheerys/metube-mobile.git
cd metube-mobile
flutter pub get

# debug
cd apps/metube_super && flutter run        # or apps/metube_lite

# release
cd apps/metube_super && flutter build apk --release
```

Release builds are signed from `apps/<app>/android/key.properties`, which is
**not** in this repository. Create your own keystore, or build debug.

On first launch, open **Settings** and enter your server URL (plus username and
password if your server is behind basic auth).

## Layout

```
packages/mt_core     pure Dart: MeTube API client, download engine, storage,
                     backup, logging — no Flutter imports
packages/mt_media    playback: audio_service handler, playback sources, position
                     and state stores, mini player
packages/mt_ui       the "Wahaj" design system: tokens, themes, shared widgets,
                     localization (ar/en)
apps/metube_lite     the family edition
apps/metube_super    the server-owner edition
docs/                the repository map and the server contract
```

Dependency direction is one-way: `apps → mt_media → mt_core`. `mt_ui` knows
nothing about the server, and `mt_core` contains no Flutter code.

## Tests

```bash
cd packages/mt_core  && dart test              # 362
cd packages/mt_media && flutter test           # 115
cd packages/mt_ui    && flutter test           #  44
cd apps/metube_lite  && flutter test           #  69
cd apps/metube_super && flutter test           # 121
```

**711 tests** at the time of writing, and `flutter analyze` is expected to be
clean. Fixtures come from real server JSON, and every fixed defect leaves behind
a test that fails on the old code.

## Translations

The UI has no hardcoded strings: everything lives in
`packages/mt_ui/lib/src/l10n/app_en.arb` and `app_ar.arb`.

Adding a language is two steps — a new `app_<code>.arb` next to those, and one
line in `packages/mt_ui/lib/src/l10n/language_names.dart` giving the language's
name **in its own language**. The settings screen builds its list from
`supportedLocales`, so a new language appears by itself. Run
`cd packages/mt_ui && flutter gen-l10n` afterwards.

Translations are very welcome — see [CONTRIBUTING.md](CONTRIBUTING.md).

## Documentation

Start with **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** — the map of the
repository: what the packages are, the rules that hold them together, where a
feature belongs, and how to run the tests. It is written in English first, with
an Arabic version below it.

[docs/SERVER-API.md](docs/SERVER-API.md) is the contract with the MeTube server
— every request and response, the local storage schema, and a list of traps that
each cost a debugging session to find. Read it before touching networking or
storage code.

The project's working language is Arabic; both documents are written in English,
and issues and pull requests are welcome in either language.

## Credits

- [MeTube](https://github.com/alexta69/metube) by alexta69 — the server these
  apps are clients for (AGPL-3.0).
- [yt-dlp](https://github.com/yt-dlp/yt-dlp) — what MeTube uses to do the actual
  downloading (Unlicense).
- The Flutter and Dart teams, and the authors of the packages listed in each
  `pubspec.yaml`.

## License

[GPL-3.0](LICENSE) — Copyright (C) 2026 Yasir Sagheer.

This program is free software: you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation, either version 3 of the License, or (at your option) any later
version. It is distributed **without any warranty**; see the license for
details.

---

## بالعربية

تطبيقا أندرويد لسيرفر [MeTube](https://github.com/alexta69/metube) ذاتي
الاستضافة، في مستودع واحد (Flutter monorepo).

> **غير رسمي**: المشروع لا يتبع MeTube ولا yt-dlp ولا يمثّلهما، وإنما هو عميل
> مستقل يتحدث إلى سيرفر MeTube عبر واجهته البرمجية. الاسم يُذكر لبيان ما
> يتصل به التطبيقان لا أكثر.

- **MeTube Lite** — نسخة العائلة: يحمّل الملف للجهاز ثم **ينظّف السيرفر**.
- **MeTube Super** — نسخة مالك السيرفر: بثّ، ومكتبة موحّدة من `/history` مع
  الفهرس المحلي، ووسوم، وتحميل دفعي، وإتاحة دون اتصال، وتبديل بين عناوين
  السيرفر.

الواجهة **بالعربية والإنجليزية** وبتخطيط يبدأ من اليمين. خريطة المستودع في
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) وعقد السيرفر في
[docs/SERVER-API.md](docs/SERVER-API.md) — كلاهما بالإنجليزية، والمساهمات
مرحّب بها بالعربية أو الإنجليزية. راجع [CONTRIBUTING.md](CONTRIBUTING.md).
