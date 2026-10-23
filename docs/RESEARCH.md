# Research report: open-source Quran & Islamic apps

*Prepared before implementation, October 2026. Scope: what the best Quran and
Islamic apps do, which parts are open source and under what licence, which
data sources may legally be redistributed, and what Mishkah should adopt,
improve or avoid.*

> **Method and limits.** Sources were package registries (npm, pub.dev,
> PyPI), GitHub repositories cloned over git, F-Droid listings, project
> READMEs and licence files, and web searches. The build sandbox could not
> reach several sites directly (tanzil.net, quran.com API, alquran.cloud,
> everyayah.com). Statements about those services come from their published
> documentation and secondary sources, and are flagged where they could not
> be verified first-hand. Proprietary apps were assessed from their public
> feature descriptions only. None of their code or assets were used.

---

## 1. Landscape

### 1.1 Open-source apps

| App | Platform / stack | Licence | Strengths worth learning from | Weaknesses |
|---|---|---|---|---|
| **Quran for Android** (quran/quran_android, “Quran by Quran.com”) | Android, Kotlin/Java | **GPL-3.0** (code). Data under its authors' licences, typically CC BY-NC-ND | Gold standard of mushaf reading: page images, gapless audio with verse timing, bookmarks with tags, translations and tafsir from QuranEnc and KSU | Image-based pages are heavy (~100+ MB per riwaya). No hifz, adhkar or prayer tools. Historic F-Droid blocker: proprietary crash reporting |
| **Quran.com web / quran.com-frontend-next** | Next.js | MIT (front end); data via the Quran.com API | Word-by-word data, tafsir and translation catalogue, reflections (“QuranReflect”), excellent search | Online-first. API terms apply to the data |
| **Aya: Quran, Hadith & Prayer Times** (F-Droid `com.quran.aya`) | Android | **MIT** | Offline Quran with 10 qira'at, hadith, 14 prayer methods, adhan, adhkar with references, qibla | F-Droid lists an anti-feature notice. Narrower memorisation features |
| **Al-Azan** (F-Droid) | React Native | Open source | Privacy-focused adhan and qibla, reliable alarms | Prayer only |
| **Huda, Mihrab, Hisn Elmoslem** (F-Droid religion category) | Android | Open source (licences vary) | All-in-one companions; Hisn al-Muslim as a stand-alone app | Smaller scope, older UI patterns |
| **Flutter packages**: `qcf_quran_plus` / `qcf_quran_lite`, `imad_flutter` (Itqan), `quran_audio` | Flutter | See each package | QCF glyph rendering of the 604 Madani pages (pixel-exact print layout); audio with media notifications; offline-first | Libraries, not apps. QCF fonts carry King Fahd Complex terms and are large |
| **adhan / adhan-dart** (batoulapps port) | Dart | **MIT** | Astronomically precise prayer times, all major methods, high-latitude rules | — (adopted) |

### 1.2 Proprietary reference apps (features only)

| App | What users praise | Lesson for Mishkah |
|---|---|---|
| **Tarteel** | AI recitation feedback, memorisation mode, mistakes detection | A memorisation loop with mistake tracking is what users want. On-device speech recognition of Quranic Arabic is a research problem; Mishkah ships self-graded SM-2 now and lists tajweed analysis on the roadmap |
| **Ayah (iOS)** | Beautiful mushaf typography, calm design | Typography and restraint matter more than feature count |
| **Muslim Pro** | One app for everything: prayer, qibla, Quran, duas, community | Breadth wins users. Ads and data-sharing controversies lose trust. Mishkah keeps the breadth and drops the tracking |
| **Athar / similar Arabic companions** (screens supplied with the brief) | Dark navy + teal + gold UI, gradient feature tiles, prophet stories as a bookshelf, audio tafsir, stats with streaks, favourites | The visual language and information architecture are adopted *as inspiration*. No assets copied. Mishkah renders prophet stories from Quran verses instead of unsourced prose |

---

## 2. Data sources and licences

| Need | Candidates | Decision | Reason |
|---|---|---|---|
| Quran text (Uthmani, Hafs) | Tanzil Uthmani; QuranEnc (King Fahd Complex based); KFGQPC QCF glyph text; alquran.cloud | **QuranEnc Uthmani text** via npm `quran-json` 3.1.2 (CC BY-SA 4.0 packaging) | Reproducible offline (npm reachable), verified 6236 verses, contains Uthmani marks that render with Amiri Quran. Text kept **verbatim** |
| Page / juz / hizb / sajda | Tanzil metadata; `quran-meta` | **quran-meta 7.0.0** (MIT) | Machine-readable Hafs lists; verified against known boundaries in tests (2:255 → p.42, 18:1 → p.293, 36:1 → p.440, 67:1 → p.562, 114 → p.604) |
| Tafsir | Quran.com API; QUL; `spa5k/tafsir_api` | **spa5k/tafsir_api** (MIT dataset, 120+ editions): al-Muyassar bundled, others downloaded per surah through jsDelivr | Static JSON per surah = offline caching is trivial. The Muyassar copy embeds surah introductions before “[التفسير]”, which are separated at build time |
| Translations | Tanzil (non-commercial, verbatim), QuranEnc | Saheeh International and Hamidullah (Tanzil via quran-json), Piccardo (islam.js) | Mishkah is free and non-commercial, which fits Tanzil's terms. Italian chosen because the first users are in Italy |
| Hisn al-Muslim | `@kazishariar/hisnul-muslim-data` (no counts); islam.js `azkar-collection` | **islam.js** (MIT) | Has repeat counts and references (مسلم، الترمذي…), 133 categories |
| Audio | EveryAyah (per-verse MP3), mp3quran (per-surah), Quran.com CDN | **EveryAyah** | Per-verse files give exact highlighting and repeat-a-verse without timing data. Free for non-commercial use. Folder names live in one table (`lib/domain/reciters.dart`) |
| Prayer times | Aladhan API; praytimes.js (LGPL); adhan (MIT) | **adhan-dart** | Fully offline; MIT is compatible with GPL-3.0 |
| Hijri calendar | Tabular algorithm; Umm al-Qura tables | **package:hijri** (BSD-2) + tabular fallback + user offset | Matches the official Saudi calendar (verified: 1 Ramadan 1447 = 18 Feb 2026) |
| Fonts | KFGQPC Uthmanic Hafs (KFGQPC terms); Amiri Quran (OFL); Noto Naskh (OFL) | **Amiri Quran, Amiri, Readex Pro** (OFL) | Unambiguously free; good Uthmani support |

**Rejected:** QCF page fonts (≈ 600 fonts, King Fahd Complex licence unclear
for redistribution in a GPL app), page images from Quran for Android (data
not ours to redistribute), and any hadith collection without clear grading
metadata (deferred, see the roadmap).

---

## 3. Feature comparison and what Mishkah adopts

| Capability | Quran Android | Aya (F-Droid) | Muslim Pro | Tarteel | **Mishkah** |
|---|---|---|---|---|---|
| Offline mushaf | ✔ (images) | ✔ | partial | ✔ | ✔ text-based, 2 MB |
| Page mode with page turn | ✔ | ? | ✔ | ✔ | ✔ 604 pages, 3D turn |
| Verse highlighting with audio | ✔ | ? | ✔ | ✔ | ✔ per-verse files |
| Offline audio download | ✔ | ✔ | ✔ (premium) | ✔ | ✔ per surah |
| Multiple tafsir offline | ✔ | partial | partial | ✗ | ✔ 1 bundled + 11 downloadable |
| Normalised Arabic search | ✔ | ? | ✔ | ✔ | ✔ dual dagger-alef index + filters |
| Spaced-repetition hifz | ✗ | ✗ | ✗ | ✔ (AI) | ✔ SM-2 with mistakes |
| Adaptive khatma | ✗ | ✗ | basic | ✗ | ✔ re-planning, busy days |
| Reflections + map | ✗ | ✗ | ✗ | ✗ | ✔ |
| Mood-based verses | ✗ | ✗ | ✗ | ✗ | ✔ |
| Prayer times + exact adhan | ✗ | ✔ | ✔ | ✗ | ✔ 12 methods |
| Qibla | ✗ | ✔ | ✔ (AR) | ✗ | ✔ compass + fallback |
| Mosque / TV board | ✗ | ✗ | ✗ | ✗ | ✔ with iqama |
| Kids mode | ✗ | ✗ | ✔ | ✗ | ✔ stars + parent PIN |
| Home-screen widget | ✗ | ✔ | ✔ | ✗ | ✔ |
| Encrypted backup/sync | ✗ | ✗ | account | account | ✔ E2E file |
| No ads / no tracking | ✔ | ✔ | ✗ | ✔ | ✔ |

---

## 4. Architecture findings

- **Rendering text vs images.** Image mushafs are pixel-perfect but cost
  100–400 MB. Text with Amiri Quran costs 2 MB, scales to any size, supports
  TalkBack, and makes search and highlighting trivial. Mishkah renders text.
  The page grouping follows Madani boundaries, but line breaks won't match
  the print. QCF-exact pages are on the roadmap as an optional download.
- **Per-verse audio** removes the need for timing files and makes
  repeat/loop exact. The cost is many small requests, which the per-surah
  download mitigates.
- **State management.** Riverpod (compile-safe, testable, no BuildContext
  coupling) was preferred to Bloc for a feature-rich app with many small
  stores. Notifiers wrap persistence, so screens stay declarative.
- **Storage.** Hive CE (pure Dart, AES-256 cipher built in, no code
  generation) over Drift/Isar: the data is small key-value documents, and
  Isar is unmaintained. The Quran itself is an in-memory structure loaded
  from gzip JSON in an isolate (≈ 150 ms), so no database is needed for
  reading.
- **No code generation.** No `build_runner` (freezed / json_serializable /
  riverpod_generator). It keeps builds fast and contributions easy, at the
  cost of hand-written `toJson`/`fromJson`, which are covered by round-trip
  tests.

## 5. Legal checklist

- [x] Code licence chosen: GPL-3.0-or-later (same family as Quran for Android). All dependencies are GPL-compatible (MIT, BSD, Apache-2.0)
- [x] Every bundled dataset has a documented source and licence (`THIRD_PARTY_LICENSES.md`)
- [x] Texts reproduced unchanged. The only transformation (moving surah introductions out of the verse commentary) is documented and scripted
- [x] Translations from Tanzil are used non-commercially and verbatim, with attribution in the About screen
- [x] Audio is streamed or downloaded from EveryAyah at the user's request, with attribution
- [x] No assets from proprietary apps. The reference screenshots were used only for visual direction

## 6. Decisions carried into the build

1. Text mushaf with Amiri Quran, verse and page modes, page-turn animation.
2. Bundled: Quran, Muyassar, three translations, Hisn al-Muslim. Everything else downloads on demand and is cached.
3. Exclusive features: SM-2 hifz, adaptive khatma, reflections + map, mood verses, verse-sourced prophet stories, mosque mode, kids mode, focused listening, encrypted backup.
4. Privacy by default: encrypted local storage, no accounts, no analytics.
5. Deferred, honestly: AI tajweed analysis, AR qibla, community and group khatma (need servers and moderation), QCF page fonts, word-by-word translations, hadith collections. See `ROADMAP.md`.

## Sources

- quran_android licence metadata: https://awesome.ecosyste.ms/projects/github.com%2Fquran%2Fquran_android · licensing issue: https://github.com/quran/quran_android/issues/434 · F-Droid thread: https://f-droid.org/forums/topic/quran-android-2/
- Aya on F-Droid: https://f-droid.org/packages/com.quran.aya/ · F-Droid religion category: https://f-droid.org/en/categories/religion/index.html
- Flutter Quran packages: https://pub.dev/documentation/qcf_quran_plus/latest/ · https://pub.dev/packages/quran_audio · https://pub.dev/packages/imad_flutter/versions/0.1.0 · https://github.com/topics/mushaf
- Tanzil terms (secondary): https://tanzil.net/docs/_export/raw/credits · https://opus.nlpl.eu/Tanzil/corpus/version/Tanzil · https://alquran.cloud/terms-and-conditions
- quran-json README (data sources): https://github.com/risan/quran-json · islam.js credits: https://github.com/dev-ahmadbilal/islam.js · tafsir dataset: https://github.com/spa5k/tafsir_api · quran-meta: https://github.com/quran-center/quran-meta
