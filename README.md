<div align="center">

<img src="branding/png/mishkah-256.png" width="128" alt="Mishkah logo"/>

# مِشكاة · Mishkah

**An open-source, offline-first Quran app for Android, built with Flutter.**

﴿ مَثَلُ نُورِهِۦ كَمِشۡكَوٰةٖ فِيهَا مِصۡبَاحٌۖ ﴾ (النور ٣٥)

No ads · no accounts · no tracking · works offline · Arabic-first RTL with English UI

</div>

---

## Why “Mishkah”?

*Mishkah* (مِشكاة) is the lamp niche in the Verse of Light (24:35). It's short,
easy to say in Arabic and English, means something, and isn't the name of a
major Quran app. The logo is a mihrab niche holding a lamp whose light is an
eight-pointed star. See [`docs/BRAND.md`](docs/BRAND.md) for the 15 names
that were considered and the brand guidelines.

## Features

### Quran
- **Full mushaf** in Uthmani script (Amiri Quran font). Two modes:
  **verse mode** (one verse per row, optional translation) and **page mode**
  (all 604 Madani pages with a 3D page-turn animation).
- Surah, juz and hizb-quarter indexes; rubʿ and sajda markers.
- Adjustable font size; four reading backgrounds (match app, night, paper, sepia);
  the reader's top bar hides while you scroll.
- **Verse-by-verse recitation** by 18 reciters (Alafasy, al-Husary, Abdul Basit,
  al-Minshawi, al-Hudhaify, as-Sudais, ash-Shuraim, al-Muaiqly, …). The verse
  being recited is highlighted and followed automatically. Plays in the
  background with lock-screen and headset controls. Speed control, repeat a
  verse, loop a range, and **per-surah offline download**.
- **Tafsir**: al-Muyassar ships with the app. Ibn Kathir, at-Tabari,
  al-Qurtubi, as-Saʿdi, al-Baghawi, al-Wasit and al-Mukhtasar download per
  surah and are then cached offline. Asbab al-Nuzul (al-Wahidi) and an English
  Ibn Kathir are also available.
- **Translations** included: English (Saheeh International), Italian
  (Piccardo) and French (Hamidullah).
- **Search** in Arabic using everyday spelling, which also matches the Uthmani
  script (ٱلصِّرَٰطَ ← الصراط), or in the translation. Modes: all words,
  exact phrase, any word. Filters: surah, juz, Meccan/Medinan.
- Bookmarks with collections, copy, and share a verse as a styled image.

### Prayer
- Prayer times computed on the device by the `adhan` library: 12 calculation
  methods, Hanafi/standard Asr, high-latitude rules, per-prayer minute offsets.
- Exact adhan notifications, an optional reminder before adhan, re-scheduled
  after reboot.
- **Qibla compass** with smoothing, alignment haptic, calibration hint, and a
  bearing dial when the device has no magnetometer.
- **Travel mode**: when you're more than 50 km from your saved place, the app
  offers to update the times.
- Umm al-Qura Hijri calendar with a ±2-day adjustment.
- **Mosque / TV mode**: a full-screen board with a large clock, today's times,
  a countdown to the next adhan and an iqama countdown. Keeps the screen on.

### New in 1.3
- **Colour-coded tajweed** in the reader (verse and page modes), computed for
  every verse with the open quran.ws tajweed engine; colour guide included.
- **Word meanings**: long-press any word for its English meaning and
  transliteration, and the verse's difficult words from *As-Siraj fi Bayan
  Gharib al-Quran*.
- **Recitation test**: recite from memory and the app follows word by word
  with the phone's speech recogniser, revealing skipped words in red, with
  hints and a score. From the verse menu, the hifz screen or the home screen.
- **Real adhan sound** at every prayer (full or short public-domain
  recordings, notification tone, or silent), a test button, a stop button,
  an optional iqama alert, and exact alarms scheduled two weeks ahead.
- **Ramadan mode**: day N and live countdown to iftar / end of suhoor,
  a fasting log for every day of Ramadan, make-up (qada) fasts, a Ramadan
  khatma plan and the iftar dua.
- **Smart reminders**: Al-Kahf and salawat on Friday, the eve of the white
  days, Monday/Thursday, Arafah and Tasu'a/Ashura, and suhoor/iftar in
  Ramadan, each with its own switch.

### Remembrance
- **Hisn al-Muslim** with 130+ situations (morning, evening, sleep, after
  prayer, travel, distress, …): tap-to-count cards, auto-advance, progress
  bar, and completion tracking.
- **Prayer adhkar** gathered in order (opening, rukuʿ, sujud, tashahhud, after
  the salam), **Ruqyah** from the Quran and Sunnah, and favourite adhkar.
- **Hadith**: the Forty Nawawi and the Forty Qudsi bundled (Arabic + English),
  Sahih al-Bukhari and Sahih Muslim as optional downloads; search, copy, share
  as an image, favourites, and a hadith of the day.
- **Smart tasbih**: presets and custom adhkar, round targets, a daily goal,
  streaks, a 14-day history, bead and ripple animation, and haptics.

### Memorise & reflect (Mishkah's own features)
- **Hifz with spaced repetition (SM-2)**: surahs split into 3/5/10-verse
  units; review from memory, reveal verse by verse, count slips, then grade.
  Each unit is rescheduled and tracked as new / learning / young / mature.
- **Adaptive khatma**: the daily target is recalculated from what's left;
  missed days are spread across the remaining days and *busy weekdays* carry
  half the load. Shows ahead/behind schedule, a 14-day chart, and a shareable
  progress card.
- **Reflection companion**: personal notes on any verse, tagged by topic,
  shareable as an image, and browsable as a **reflection map** linking topics
  to verses.
- **Verses for your state**: choose sad, anxious, afraid, grateful, losing
  hope, patient or in distress, and get verses with Tafsir al-Muyassar.
- **Stories of the prophets** as a bookshelf of the 25 prophets named in the
  Quran, filterable (Ulul ʿAzm / messengers / prophets). Each story is a guided
  journey through the Quran passages, with the Muyassar explanation for each
  verse and audio for the passage. No invented narrative.
- **Focused listening**: only the verse being recited, cross-fading as the
  recitation moves on.
- **Kids mode**: Juz ʿAmma with large text, repeat-listening and stars a parent
  awards (listened / recited along / from memory), with an optional parent PIN
  and a celebration animation.
- **Statistics & badges**: streaks, verses read, reading minutes, prayers
  logged over 30 days, tasbih totals, and 13 achievements with a Lottie
  celebration. Everything is computed on the device.
- **“My day”** checklist: prayers, morning/evening adhkar, khatma portion,
  due hifz reviews, and tasbih goal.
- Verse, dua and dhikr of the day; “did you know?” tips; a weekly summary
  (prayers out of 35, active days); countdowns to the next Hijri occasion.
- **Prophetic Sira through the Quran**: four sections (who he is ﷺ, his life,
  his battles, his household), each event told by its verses and Tafsir
  al-Muyassar.
- **Audio tafsir**: Tafsir al-Muyassar read aloud verse by verse by the
  device's Arabic voice (offline when the voice is installed).
- **Live Quran radio** (MP3Quran.net) and **religious clips**: shelves of
  recitations, reminders, ibtihalat and tafsir that play inside the app
  (YouTube's official embedded player, plus MP3Quran video recitations).
- **Hijri calendar** with occasions, the white days and Monday/Thursday fasts;
  a **month table** of prayer times.
- **Sadaqa jariya**: log deeds dedicated to loved ones and share the app.
- **Favourites** in one place: verses, hadiths and adhkar with filters.

### Platform
- **Home-screen widget**: verse of the day and today's prayer times (native
  Android `AppWidgetProvider`).
- **Privacy**: all user data is in AES-256 encrypted Hive boxes, with the key
  in the Android Keystore. No analytics and no accounts.
- **End-to-end encrypted backup / sync**: export a PBKDF2 + AES-GCM encrypted
  file, keep it in Google Drive or anywhere, and restore it on another device.
- **Accessibility**: TalkBack labels on verses and controls, system text
  scaling (clamped so layouts stay usable), a high-contrast theme, a
  reduce-motion setting (it also honours Android's “remove animations”),
  48 dp touch targets, and haptics that can be turned off.
- Arabic and English UI, fully RTL-aware. The mushaf is always RTL.

## Screens

The UI follows the dark navy / teal / gold design language shown in
`docs/DESIGN.md` (home, mushaf, prayer card, azkar, tasbih, prophets
bookshelf, stats). Golden images of key components are in
`test/golden/goldens/`.

## Build & run

Requirements: Flutter **3.47** (stable), Android SDK (API 36), JDK 17.

```bash
flutter pub get
flutter run                      # debug on a device/emulator
flutter build apk --release      # build/app/outputs/flutter-apk/app-release.apk
flutter build appbundle          # Play Store bundle
```

Release signing is explained in [`docs/RELEASE.md`](docs/RELEASE.md). Without a
keystore the release build is signed with the debug key so it still installs.

**CI**: `.github/workflows/android.yml` runs analysis and tests, then builds
debug and release APKs (split per ABI, plus a universal APK) and an App
Bundle on every push. Download them from the workflow run's *Artifacts*.
Tags matching `v*` also publish a GitHub Release.

## Project structure

```
lib/
  main.dart, app/            app widget, providers (Riverpod), bootstrap
  core/                      theme, motion system, l10n, shared widgets, utils
  domain/                    pure logic: prayer times, qibla, SM-2, khatma,
                             search, achievements, models (no Flutter imports
                             except @immutable)
  data/                      Quran text + metadata, translations/tafsir
                             repository, azkar, encrypted local storage
  services/                  audio, notifications, location, backup, widget
  features/<feature>/        screens (presentation layer)
assets/data/                 offline Quran, tafsir, translations, azkar
assets/fonts/, assets/lottie/, assets/branding/
tool/data/                   reproducible data build
tool/branding/               logo, icon, splash and Lottie generators
test/unit, test/widget, test/golden, integration_test/
docs/                        research, brand, design, guides, roadmap
```

See [`docs/DEVELOPER_GUIDE.md`](docs/DEVELOPER_GUIDE.md) for architecture
decisions (Riverpod, Hive CE, no code generation) and how to add a language,
a reciter or a tafsir.

## Documentation

- [Research report](docs/RESEARCH.md): open-source Quran apps compared, what
  was adopted, and licences
- [Brand guidelines](docs/BRAND.md) · [Design & animation spec](docs/DESIGN.md)
- [User guide](docs/USER_GUIDE.md) · [Developer guide](docs/DEVELOPER_GUIDE.md)
- [Project plan](docs/PLAN.md) · [Roadmap](docs/ROADMAP.md) · [Release & signing](docs/RELEASE.md)
- [Third-party licences & data sources](THIRD_PARTY_LICENSES.md)

## Licence

Code: **GPL-3.0-or-later**. GPL keeps every fork of a Quran app open and
ad-free, and matches the most established open-source Quran app (Quran for
Android). Data and fonts keep their own licences; see
`THIRD_PARTY_LICENSES.md`.

Contributions are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) and the
[Code of Conduct](CODE_OF_CONDUCT.md).
