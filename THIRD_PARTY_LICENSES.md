# Third-party licences and data sources

Mishkah's own source code is licensed under **GPL-3.0-or-later** (see `LICENSE`).
Everything below is third-party material that ships inside the app or is
fetched by it at run time. Nothing was copied from a source whose licence
does not allow redistribution.

## Religious texts and data (bundled in `assets/data/`)

| File | Content | Source | Licence / terms |
|---|---|---|---|
| `quran_uthmani.json.gz` | Quran text, Uthmani script (Hafs) | [QuranEnc.com](https://quranenc.com) text as packaged by [`quran-json` 3.1.2](https://github.com/risan/quran-json) by Risan Bagja Pradana | CC BY-SA 4.0 (packaging). The text is reproduced **unchanged**. |
| `tr_en_sahih.json.gz` | English translation, Saheeh International | [Tanzil.net](https://tanzil.net/trans/en.sahih) via `quran-json` | Tanzil terms: verbatim redistribution with attribution, non-commercial; CC BY-SA 4.0 packaging |
| `tr_fr_hamidullah.json.gz` | French translation, Muhammad Hamidullah | [Tanzil.net](https://tanzil.net/trans/fr.hamidullah) via `quran-json` | as above |
| `tr_it_piccardo.json.gz` | Italian translation, Hamza Roberto Piccardo | [`islam.js` 1.3.0](https://github.com/dev-ahmadbilal/islam.js) (credits surahquran.com / Kaggle “Holy Quran in 44 languages”) | MIT (package) |
| `tafsir_muyassar.json.gz` | التفسير الميسر (King Fahd Glorious Quran Printing Complex) + surah introductions | [`spa5k/tafsir_api`](https://github.com/spa5k/tafsir_api) (sources quran.com / QUL) | MIT (dataset); text reproduced unchanged |
| `azkar.json.gz` | حصن المسلم – Saʿid ibn Wahf al-Qahtani | `islam.js` 1.3.0 `azkar-collection` | MIT (package) |
| `hadith.json.gz` | الأربعون النووية and الأحاديث القدسية الأربعون (Arabic + English) | [`fawazahmed0/hadith-api`](https://github.com/fawazahmed0/hadith-api) editions `ara-nawawi`, `ara-qudsi`, `eng-nawawi`, `eng-qudsi` | The Unlicense (public domain); text reproduced unchanged |
| `tajweed.json.gz` | Tajweed colour runs for every verse, computed on our own Uthmani text | Engine [quran-ws/quran-tajweed](https://github.com/quran-ws/quran-tajweed) `packages/core` (MIT) running the rule corpus `@quran.ws/tajwid-rules` 0.1.0 (CC BY 4.0, with a standing waiver of attribution inside products; attributed here anyway). See `tool/data/tajweed/README.md` | MIT / CC BY 4.0 |
| `wbw_en.json.gz` | English word-by-word meanings and transliteration | Quran.com data as packaged in `@kmaslesa/holy-quran-word-by-word-full-data` 1.0.6 | ISC (package); content credited to Quran.com |
| `meta.json` | Hafs page, juz, hizb-quarter and sajda boundaries | [`quran-meta` 7.0.0](https://github.com/quran-center/quran-meta) | MIT |

`tool/data/build_data.py` regenerates every file from those sources and
documents the only transformation applied (moving the surah introductions of
the Muyassar dataset out of the verse commentary).

The prophets index (`lib/domain/prophets.dart`), the Sira index
(`lib/domain/sira.dart`), the Hijri occasions list (`lib/domain/occasions.dart`), the “verses for your state”
list and the daily verse/dua rotation (`lib/domain/daily_content.dart`) are
**references only** (surah:verse ranges) written for Mishkah; the verses are
always rendered from the bundled mushaf text, and explained with Tafsir
al-Muyassar. No religious text was written for this app.

## Downloaded at run time (not bundled)

| What | From | Terms |
|---|---|---|
| Tafsir Ibn Kathir, at-Tabari, al-Qurtubi, as-Saʿdi, al-Baghawi, al-Wasit, al-Mukhtasar, Gharib al-Quran, English Ibn Kathir, Asbab al-Nuzul (al-Wahidi), Italian Mukhtasar | `cdn.jsdelivr.net/gh/spa5k/tafsir_api` | MIT (dataset) |
| Verse-by-verse recitations (18 reciters) | [EveryAyah.com](https://everyayah.com) | Free for non-commercial use with attribution |
| Sahih al-Bukhari, Sahih Muslim (Arabic, optional download) | `cdn.jsdelivr.net/gh/fawazahmed0/hadith-api` | The Unlicense (public domain) |
| Live Quran radio list and streams | [MP3Quran.net public API](https://mp3quran.net/api/v3/radios) | Free public API; streams belong to their broadcasters and are played, not stored |
| Religious clips (YouTube) | Video lists read from public YouTube search pages; played with YouTube's official IFrame embedded player inside the app (views count for the publisher); thumbnails from `i.ytimg.com`. Nothing is downloaded or re-hosted | YouTube Terms of Service / embedded-player policy; content belongs to its publishers |
| Video recitations | [MP3Quran.net API](https://www.mp3quran.net/api/v3/videos), streamed from its servers | Free public API; content belongs to MP3Quran.net and the reciters |

The audio tafsir is Tafsir al-Muyassar (bundled) read aloud by the device's own
text-to-speech engine; no recordings are distributed.

## Adhan recordings (`android/app/src/main/res/raw/`)

Two public-domain recordings from Wikimedia Commons (CC0 1.0): “Beautiful
adhan” by Adam-synagda (unmodified) and “Adhan.ogg” (volume raised). Details
and checksums in [`licenses/ADHAN_RECORDINGS.md`](licenses/ADHAN_RECORDINGS.md).

## Fonts (`assets/fonts/`, licences in `licenses/`)

| Font | Author | Licence |
|---|---|---|
| Amiri Quran | Khaled Hosny / Amiri Project | SIL OFL 1.1 |
| Amiri (Regular, Bold) | Khaled Hosny / Amiri Project | SIL OFL 1.1 |
| Readex Pro (static 400/500/700 instances generated with fontTools) | Thomas Jockin & the Readex Pro authors | SIL OFL 1.1 (Reserved Font Name “RevReading Lexend” is not used) |

## Dart / Flutter packages

All dependencies come from pub.dev under permissive licences; the in-app
“Open-source licences” page (Settings → About) lists each one with its full
text, generated by Flutter from the packages' `LICENSE` files.

| Package | Licence | Use |
|---|---|---|
| flutter, flutter_localizations | BSD-3-Clause | UI framework |
| flutter_riverpod | MIT | State management |
| hive_ce, hive_ce_flutter | Apache-2.0 | Encrypted local storage |
| flutter_secure_storage | BSD-3-Clause | Storage encryption key in Android Keystore |
| just_audio, just_audio_background (audio_service) | MIT | Recitation playback, lock-screen controls |
| flutter_local_notifications, timezone, flutter_timezone | BSD-3-Clause / BSD-2 / Apache-2.0 | Adhan & reminders |
| adhan | MIT | Prayer-time astronomy (port of batoulapps/adhan) |
| hijri | BSD-2-Clause | Umm al-Qura calendar tables |
| geolocator | MIT | Location |
| flutter_compass | MIT | Compass heading for qibla |
| lottie | MIT | Celebration animation |
| scrollable_positioned_list | BSD-3-Clause | Jump to a verse |
| share_plus, path_provider | BSD-3-Clause | Sharing images, file paths |
| file_picker | MIT | Restoring backups |
| http | BSD-3-Clause | Downloads |
| flutter_tts | MIT | Audio tafsir via the device's text-to-speech |
| url_launcher | BSD-3-Clause | Opening YouTube / web links |
| youtube_player_iframe (webview_flutter) | BSD-3-Clause | In-app YouTube playback via the official IFrame API |
| video_player | BSD-3-Clause | In-app MP4 playback (MP3Quran video recitations) |
| speech_to_text | BSD-3-Clause | Recitation test through the phone's speech recogniser |
| wakelock_plus | BSD-3-Clause | Mosque mode / focused listening |
| vibration | BSD-2-Clause | Tasbih round haptics |
| home_widget | BSD-3-Clause | Android home-screen widget |
| crypto, encrypt (pointycastle) | BSD-3-Clause / BSD-3-Clause / MIT | Backup encryption (PBKDF2 + AES-GCM) |
| intl | BSD-3-Clause | Date formatting (via localisations) |
| flutter_launcher_icons, flutter_native_splash (dev) | MIT | Icon & splash generation |

## Original artwork

The Mishkah logo, adaptive icon, splash artwork and the celebration Lottie
animation were created for this project (`tool/branding/`) and are released
under the project licence.
