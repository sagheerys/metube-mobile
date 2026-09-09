<!-- Write in English or Arabic. Both are read. -->

## What this changes

<!-- One or two sentences. If it fixes an issue, link it. -->

## Checklist

- [ ] `flutter analyze --no-pub` is clean
- [ ] All five test suites pass (`mt_core`, `mt_media`, `mt_ui`, `metube_lite`, `metube_super`)
- [ ] New UI text lives in **both** `app_en.arb` and `app_ar.arb`, and `flutter gen-l10n` has been run
- [ ] Colours and spacing come from the tokens, not from literals — and the screen was checked in **dark mode** as well as light
- [ ] A change shared through `mt_core` / `mt_ui` / `mt_media` was checked in **both** apps
- [ ] A fixed defect leaves behind a test that fails on the old code

<!--
The reasoning behind each of these lives in CONTRIBUTING.md. The dark-mode
and both-apps items are the two that get forgotten most often, and both
produce defects that no automated check will catch for you.
-->
