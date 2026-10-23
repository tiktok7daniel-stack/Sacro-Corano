/// Arabic text helpers: digit conversion and search normalisation.
library;

const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

/// Converts western digits in [input] to Arabic-Indic digits.
String toArabicDigits(Object input) {
  final s = input.toString();
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r >= 0x30 && r <= 0x39) {
      b.write(_arabicDigits[r - 0x30]);
    } else {
      b.writeCharCode(r);
    }
  }
  return b.toString();
}

/// Formats a number for the given language code.
String localNum(Object n, String lang) => lang == 'ar' ? toArabicDigits(n) : n.toString();

// Harakat, Quranic annotation marks, tatweel and small high letters.
final _diacritics = RegExp(
  '[ؐ-ًؚ-ٟۖ-ۜ۟-۪ۤۧۨ-ۭـ࣓-ࣿ]',
);

/// Normalises Arabic (including Uthmani script) for loose matching.
///
/// When [daggerAsAlef] is true the superscript alef (U+0670) becomes a full
/// alef, so "ٱلصِّرَٰطَ" matches "الصراط"; otherwise it is dropped, so
/// "ٱلرَّحۡمَٰنِ" matches "الرحمن". The search index keeps both variants.
String normalizeArabic(String input, {bool daggerAsAlef = false}) {
  var s = input;
  s = s.replaceAll('ٰ', daggerAsAlef ? 'ا' : '');
  s = s.replaceAll(_diacritics, '');
  s = s
      .replaceAll(RegExp('[ٱأإآٲٳ]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ی', 'ي')
      .replaceAll('ئ', 'ي')
      .replaceAll('ؤ', 'و')
      .replaceAll('ة', 'ه')
      .replaceAll('ۀ', 'ه')
      .replaceAll('ء', '')
      .replaceAll('ـ', '')
      // Uthmani small waw / yaa used as long vowels.
      .replaceAll('ۥ', 'و')
      .replaceAll('ۦ', 'ي');
  s = s.replaceAll(RegExp(r'[^ء-يa-zA-Z0-9\s]'), ' ');
  return s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// True when [text] contains Arabic letters.
bool isArabic(String text) => RegExp('[؀-ۿ]').hasMatch(text);
