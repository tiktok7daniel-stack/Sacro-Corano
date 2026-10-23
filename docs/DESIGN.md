# Design & motion specification

## Principles

1. **Arabic first, RTL native.** Every layout uses directional insets
   (`EdgeInsetsDirectional`, `AlignmentDirectional`). The mushaf is always
   RTL, even with the English UI.
2. **Calm night palette** (navy, teal, gold), with paper and sepia for
   long reading.
3. **One-handed.** The five daily destinations are in the bottom bar.
   Everything else is one tap from Home, grouped as *Every day*, *Listen &
   remember*, *Reflect & memorise* and *Family & mosque*.
4. **Motion with purpose**: it confirms an action, shows continuity, or
   celebrates. Never decoration that costs battery.

### Why bottom navigation and not a drawer

Daily use is dominated by four places: Home, the mushaf, prayer times and
adhkar. A bottom `NavigationBar` keeps them in thumb reach and visible. A
drawer hides them behind an extra tap and fits RTL one-handed use poorly.
Settings is the fifth tab because reading preferences are changed often.

## Screens

| Screen | Key elements |
|---|---|
| Splash | Animated logo, name, 24:35 over a star field |
| Onboarding sheet | Language, location (GPS or city), privacy promise, notification permission. Everything can be skipped |
| Home | Greeting and Hijri date · prayer card (next prayer, live countdown, day timeline) · continue reading / my day / Ramadan · verse, dua and dhikr of the day carousel · feature grids |
| Quran index | Search field · tabs: surahs / juz / hizb-quarters |
| Reader – verse mode | Ornamental surah header, basmala, verses with ۝ markers, translation, sajda and rubʿ markers, highlighted current verse, mini player |
| Reader – page mode | 604 pages, page header (surah names, juz), page number, 3D page turn, tap a verse for actions |
| Verse actions sheet | Play from here, repeat, tafsir, word meanings, save, reflect, share image, copy, memorise |
| Tafsir sheet | Edition chips, verse with translation, tafsir text, next/previous, surah introduction, download for offline |
| Search | Scope, mode, revelation, juz and surah filters; highlighted matches |
| Prayer | Prayer card, day navigation, six times with notify toggle and prayed checkbox; settings screen |
| Qibla | Rotating dial with Kaaba marker, glow and haptic when aligned, bearing, distance, calibration hint |
| Mosque mode | Full-screen clock, Hijri/Gregorian dates, next adhan or iqama countdown, times row |
| Adhkar | Six featured gradient tiles (with ✓ when done today), searchable list of all categories |
| Adhkar reader | One card per dhikr, tap anywhere to count, progress ring, auto-advance, completion celebration |
| Tasbih | Dhikr chips, bead ring, big count, rounds; today / streak / history |
| Prophets | Bookshelf of 25 books, filters; story = verse + Muyassar steps with progress |
| Hifz | Due today, stats, stage bar per surah; session: cue, reveal, mistakes counter, four grade buttons |
| Khatma | New plan: days and busy days. Plan: progress ring, today / ahead-behind / count, 14-day bars, share |
| Reflection companion | List with topic chips, or radial map |
| Verses for your state | Mood chips → verse cards with tafsir |
| Stats | Three hero tiles, 30-day bar chart, prayers per prayer, totals, badges |
| Kids | Colourful Juz ʿAmma grid with stars; surah page with big text, listen, award stars; parent PIN |
| Settings | Appearance, Quran, prayer and reminders, backup and sync, about |

## Animation inventory

All durations come from `Motion.of(context)` (`lib/core/motion.dart`). They
become zero when the user turns on *Reduce motion* or Android's *Remove
animations*.

| Where | What | How |
|---|---|---|
| Splash | Niche stroke draws, glass fades, star turns and blooms with easeOutBack, name slides in, star field drifts and twinkles | `CustomPainter` (`MishkahLogo`, `_StarField`), 1.5 s |
| Page transitions | Shared-axis fade + 8 % RTL-aware slide, outgoing page dims | `fadeThrough()` route |
| Tab switch | Fade + 98.5 % → 100 % scale | `AnimatedSwitcher` |
| Lists and grids | Staggered fade-up (40 ms steps, capped) | `FadeSlideIn.indexed` |
| Buttons and tiles | Press-scale 0.96 + selection haptic | `Pressable` |
| Prophet books | Hero flight from shelf to story | `Hero` |
| Reader chrome | Top bar slides away while scrolling, double-tap toggles it in page mode | `AnimatedSlide` |
| Mushaf page mode | 3D page turn around the spine, shading on the fold | `_PageTurn` (Matrix4 perspective) |
| Playing verse | Highlight fades in, list auto-scrolls to the reciter | `AnimatedContainer`, `scrollTo` |
| Focused listening | Verse cross-fades and scales in | `AnimatedSwitcher` |
| Mini player | Slides up from the bottom | `SlideTransition` |
| Prayer card | Pulsing “live” dot, active time dot grows | `FadeTransition`, `AnimatedContainer` |
| Qibla | Dial rotates (unwrapped angle, no 359→0 spin), glow when aligned, heavy haptic once | `TweenAnimationBuilder`, `AnimatedContainer` |
| Tasbih | Newest bead pops, ripple ring, count pulses, vibration pattern on round | `_BeadRing` painter |
| Adhkar | Ring fills, count flips to ✓, auto-advance page | Tween + `AnimatedSwitcher` + `PageController` |
| Celebrations | Gold star bloom, glow, 12 sparks | **Lottie** `assets/lottie/celebration.json` (generated by `tool/branding/build_lottie.py`) |
| Stats | Bars grow with stagger, progress bars fill, counters roll | `CustomPainter`, `AnimatedCount` |
| Khatma | Sweep-gradient ring fills | `_Ring` painter |
| Reflection map | Nodes fly out from the centre, links draw | `_MapPainter` |
| About | Logo draws itself | `MishkahLogo(progress)` |

**Lottie / Rive choice:** one Lottie file covers the celebration moments. The
rest is built with Flutter animations and custom painters, which are smaller,
themeable, and switch off cleanly with reduce motion. Rive was not added: a
second runtime (~1 MB) didn't buy anything the painters don't already do.

## Accessibility checklist

- Every verse is a semantic button announcing “verse n” and its text. Icon
  buttons have tooltips, which also serve as TalkBack labels.
- Text scale follows the system, clamped to 0.85–1.6 so grids stay usable.
  The mushaf has its own 20–52 sp slider.
- High-contrast theme toggle. All text on tiles is white on saturated colours
  (≥ 4.5:1 on the darker stop).
- Touch targets ≥ 48 dp (`MaterialTapTargetSize.padded`).
- Tasbih and adhkar counting accept a tap anywhere on a large area (motor
  accessibility).
- Haptics can be turned off.
