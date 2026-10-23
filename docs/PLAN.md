# Project plan

Two-week sprints, one maintainer plus contributors. Status as of the first
commit (October 2026).

| Sprint | Scope | Estimate | Status |
|---|---|---|---|
| 0 | Research, licences, data pipeline, brand (name, logo, palette, fonts) | 1 week | ✅ Done |
| 1 | Architecture, theme, motion system, l10n, storage, Quran data and index, reader (verse mode), search | 2 weeks | ✅ Done |
| 2 | Page mode with page turn, audio (18 reciters, background, highlight, downloads), tafsir and translations | 2 weeks | ✅ Done |
| 3 | Prayer times, notifications, qibla, travel mode, Hijri, mosque mode, home widget | 2 weeks | ✅ Done |
| 4 | Adhkar, tasbih, hifz (SM-2), adaptive khatma, reflections and map, mood verses, prophets, kids mode, stats and badges | 2 weeks | ✅ Done |
| 5 | Encrypted backup, onboarding, accessibility pass, unit/widget/golden/integration tests (≥ 85 %), CI/CD, docs | 2 weeks | ✅ Done |
| 6 | Device QA on Android 8–15, performance profiling (cold start, jank), store listing assets, first signed release | 1–2 weeks | ⏳ Next: needs physical devices |
| 7+ | Roadmap items (QCF pages, word-by-word, tajweed analysis, community features) | — | 📋 See ROADMAP.md |

## Quality gates

| Gate | Target | Current |
|---|---|---|
| Static analysis | 0 issues with `--fatal-infos` | ✅ 0 |
| Line coverage | ≥ 85 % | ✅ 85.8 % (133 tests) |
| APK size (universal, release) | < 60 MB | Expected ~25–30 MB (3 MB data, 1.3 MB fonts + Flutter engine for 3 ABIs). Measured by CI |
| Cold start | < 2.5 s | Quran parsing runs in an isolate (~150 ms); splash minimum 1.7 s (0 with reduce motion). Needs on-device measurement |
| Frame rate | 60 fps | Animations are transform/opacity based, and painters repaint only on change. Needs profiling on low-end devices |
