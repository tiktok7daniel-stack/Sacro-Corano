# Contributing to Mishkah

Jazakum Allahu khayran for helping! Every contribution, whether code, translation, design, testing or reporting a typo in a string, is welcome.

## Ground rules for religious content
1. **Never type or paste religious text by hand.** Quran text, translations, tafsir and adhkar come only from documented, licensed sources via `tool/data/build_data.py`.
2. New data needs its source, licence and a regeneration step in `THIRD_PARTY_LICENSES.md`.
3. Curated lists (prophet passages, mood verses, daily verses) store **references only**, and must pass the reference tests in `test/unit/data_test.dart`.
4. If you find an error in a text, open an issue citing the upstream source. Fixes go upstream first.

## Workflow
1. Fork, then create a branch: `feat/…`, `fix/…`, `docs/…`.
2. `flutter pub get`, then make your change.
3. `flutter analyze --fatal-infos` and `flutter test` must pass. Add tests for new logic. Coverage must stay ≥ 85 %.
4. If you changed a UI component covered by goldens, regenerate on Linux: `flutter test --update-goldens test/golden`.
5. Open a pull request using the template. Keep PRs focused.

## Code
- Read `docs/DEVELOPER_GUIDE.md` (architecture, how to add a language, reciter or tafsir).
- Directional layouts only (RTL first). Strings go through `context.tr()`, and every language table gets the key.
- Animations use `Motion.of(context)` so *reduce motion* works.

## Translating the UI
Add or extend a table in `lib/core/l10n/strings_data.dart`. The l10n test lists any missing keys.

## Licence
By contributing you agree that your code is licensed under GPL-3.0-or-later.
