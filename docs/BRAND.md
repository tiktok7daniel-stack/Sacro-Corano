# Mishkah brand guidelines

## 1. Name

### Candidates considered

| # | Arabic | Latin | Meaning / rationale | Verdict |
|---|---|---|---|---|
| 1 | **مِشكاة** | **Mishkah** | The lamp niche of the Verse of Light (24:35): light kept safe and shining | **Chosen** |
| 2 | نور | Noor | Light | Too common; hundreds of apps use it |
| 3 | تِبيان | Tibyan | Clarification (16:89) | Good meaning, hard for non-Arabic speakers |
| 4 | رَتِّل | Rattil | “Recite (it) slowly” (73:4) | Narrows the app to recitation |
| 5 | سَكينة | Sakina | Tranquillity | Very common in the app stores |
| 6 | هُدى | Huda | Guidance | Already an F-Droid app name |
| 7 | بَصائر | Basa'ir | Insights (6:104) | Also a TV channel name |
| 8 | الفُرقان | Furqan | The Criterion | Already used by many Quran apps |
| 9 | ذِكرى | Dhikra | Reminder | Ambiguous next to dhikr counters |
| 10 | آية | Aya | Sign / verse | Already taken (F-Droid “Aya”) |
| 11 | مِحراب | Mihrab | Prayer niche | Already an F-Droid app (“Mihrab”) |
| 12 | مِصباح | Misbah | Lamp | Similar to many shop names |
| 13 | ريحانة | Rayhana | Sweet basil | Doesn't suggest the Quran |
| 14 | أَثَر | Athar | Trace / legacy | Already the name of a popular app |
| 15 | وِرد | Wird | Daily portion | Too narrow, and has an English homonym |

### Why Mishkah

- **Meaning:** it comes from the Quran itself (﴿مَثَلُ نُورِهِۦ كَمِشۡكَوٰةٖ فِيهَا مِصۡبَاحٌۖ﴾). It is a vessel for light, which is what the app tries to be for the mushaf.
- **Pronunciation:** two syllables, and comfortable in Arabic, English, Italian and Urdu. The Latin spelling *Mishkah* matches the common transliteration.
- **Distinctiveness:** no major Quran app uses it. It also suggests a visual (an arched niche with a lamp), which gives a strong, simple logo.
- **Availability:** the package id is `app.mishkah.quran`. Check store listings before publishing; this could not be verified from the build environment.

## 2. Logo

- `branding/logo.svg`: full-colour app icon (rounded square, night background)
- `branding/logo-mark.svg`: mark only, on a transparent background
- `branding/logo-monochrome.svg`: single colour (Android 13 themed icon, notification icon)
- `branding/png/mishkah-{16,32,48,64,128,256,512,1024}.png`
- Adaptive icon: foreground `assets/branding/icon-foreground-1024.png` (mark inside the 66 % safe zone), background `#0A0E15`, monochrome layer included

The mark is generated from a single definition (`tool/branding/build_branding.py`),
and the Dart painter `MishkahLogo` uses the same 1024-unit geometry. To change the
logo, edit both files, then run:

```bash
python3 tool/branding/build_branding.py
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

**Construction:** a pointed arch (mihrab) in a 34-unit gold stroke on a 1024 grid,
a base line, a lamp chain, a teal glass globe, and an eight-pointed star (two
squares at 45°) with a soft radial glow. Keep clear space of ¼ of the mark's width
on every side. Don't recolour the star, don't add text inside the mark, and
don't place it on busy photos.

## 3. Colour

| Token | HEX | Use |
|---|---|---|
| Ink | `#0A0E15` | App background (night), icon background |
| Night | `#0F1520` | Reading page (night) |
| Surface | `#17212B` | Cards |
| Surface high | `#1F2B36` | Elevated surfaces, mini player |
| Outline | `#2A3843` | Borders, empty progress |
| Teal | `#1E7F8A` | Primary brand colour |
| Teal bright | `#34A9B4` | Interactive accents on dark backgrounds |
| Teal deep | `#0F4C57` | Primary on light backgrounds |
| Gold | `#D6B26E` | Highlights, the selected tab, the logo |
| Gold deep | `#A9833F` | Gold on light backgrounds |
| Text high / mid / low | `#EDEAE3` / `#A7B0BA` / `#6E7A86` | Text on dark backgrounds |
| Paper | `#F7F2E7` · `#FFFBF2` | Light theme, paper reading mode |
| Sepia | `#F1E4C8` (ink `#3B2F1E`) | Sepia reading mode |

Feature tiles use two-stop gradients (see `lib/core/theme/brand.dart`). They are
saturated on purpose, to help people find features at a glance. They are always
used with white text at ≥ 4.5:1 contrast on the darker stop.

## 4. Typography

| Role | Font | Notes |
|---|---|---|
| Mushaf | **Amiri Quran** | Supports Uthmani marks and ۝ verse-number ornaments |
| Adhkar, tafsir, long Arabic | **Amiri** (400/700) | Classical naskh, very readable at 17–23 sp |
| UI (Arabic & Latin) | **Readex Pro** (400/500/700) | Modern Arabic/Latin pair, clear digits |

All are SIL OFL 1.1 and bundled, so the app looks the same offline on every device.

## 5. Iconography and style

- Material Symbols (rounded) for UI icons; gold for the selected state, teal for actions.
- Corner radii: 18 (small), 24–26 (cards), 28–32 (tiles, sheets).
- No depictions of prophets or living beings in prophet stories. A bookshelf
  and verses carry the content.
- Islamic geometry is suggested (eight-pointed star, arches), not used as
  wallpaper, to keep the UI calm.

## 6. Splash

Native splash: the mark on `#0A0E15` (Android 12+ uses the 960 px icon with
content inside a 640 px circle). The Flutter splash then animates the mark
(niche drawn → lamp lit → star blooms), fades in the name, and shows 24:35 over
a slowly drifting star field. With reduce motion on, it shows the final frame.
