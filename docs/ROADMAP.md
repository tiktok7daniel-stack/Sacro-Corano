# Roadmap

## Shipped in 1.0
See the README feature list.

## Next (1.1)
- **QCF / KFGQPC page rendering** as an optional download: print-exact line
  layout of the 604 Madani pages (needs King Fahd Complex licence clearance).
- **Word-by-word** translation and tap-a-word meanings from QUL data (today
  Gharib al-Quran gives per-verse word meanings).
- **Root-based search** (Quranic Arabic Corpus morphology, GPL-compatible).
- **Adhan audio** choices for notifications (needs freely licensed recordings).
- More bundled translations (Urdu, Turkish, Indonesian, Spanish, German…) as
  optional downloads.
- More widget sizes and a quick-tasbih widget.
- Gapless whole-surah audio (mp3quran) with verse timing for reciters not on EveryAyah.

## Later (1.2+)
- **Recitation feedback (tajweed / mistakes)** with on-device speech
  recognition. Open models for Quranic Arabic are emerging; this needs
  research before promising accuracy.
- **AR qibla** (ARCore) as an optional mode.
- **Group khatma & community plans**: needs a small open-source server with
  E2E encryption and moderation. Opt-in only.
- **Automatic Google Drive sync** of the encrypted backup (needs an OAuth
  client; today the user saves the encrypted file to Drive manually).
- Hadith collections with grading metadata.
- Wear OS tile (prayer times, tasbih).
- iOS build (the codebase is Flutter; platform-specific pieces are the widget,
  notifications and audio service).

## Not planned
- Ads, analytics, or any tracking.
- Content without a documented source.
