import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Tajweed colour runs for every verse, computed offline on the bundled
/// Uthmani text by the open quran.ws tajweed engine (see
/// tool/data/tajweed/README.md). Offsets are code points.
class TajweedData {
  TajweedData(this.classes, this._ayahs);
  final List<String> classes;
  final List<List<List<int>>> _ayahs;

  /// Flat `[start, end, class, …]` for one verse (empty when none).
  List<int> runs(int surah, int ayah) {
    if (surah < 1 || surah > _ayahs.length) return const [];
    final s = _ayahs[surah - 1];
    return ayah < 1 || ayah > s.length ? const [] : s[ayah - 1];
  }

  static Future<TajweedData> load([AssetBundle? bundle]) async {
    final bytes = (await (bundle ?? rootBundle).load('assets/data/tajweed.json.gz')).buffer.asUint8List();
    return compute(parse, bytes);
  }

  @visibleForTesting
  static TajweedData parse(Uint8List bytes) {
    final j = jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>;
    return TajweedData(
      (j['classes'] as List).cast<String>(),
      [
        for (final s in j['ayahs'] as List) [for (final a in s as List) (a as List).cast<int>()],
      ],
    );
  }
}

/// One word's English meaning and transliteration.
class WordGloss {
  const WordGloss(this.meaning, this.translit);
  final String meaning;
  final String translit;
}

/// Word-by-word English meanings (Quran.com data), aligned to the words of
/// the bundled text; verses whose split differs are empty.
class WordByWord {
  WordByWord(this._ayahs);
  final List<List<List<WordGloss>>> _ayahs;

  List<WordGloss> words(int surah, int ayah) {
    if (surah < 1 || surah > _ayahs.length) return const [];
    final s = _ayahs[surah - 1];
    return ayah < 1 || ayah > s.length ? const [] : s[ayah - 1];
  }

  static Future<WordByWord> load([AssetBundle? bundle]) async {
    final bytes = (await (bundle ?? rootBundle).load('assets/data/wbw_en.json.gz')).buffer.asUint8List();
    return compute(parse, bytes);
  }

  @visibleForTesting
  static WordByWord parse(Uint8List bytes) {
    final j = jsonDecode(utf8.decode(gzip.decode(bytes))) as Map<String, dynamic>;
    return WordByWord([
      for (final s in j['ayahs'] as List)
        [
          for (final a in s as List) [for (final w in a as List) WordGloss((w as List)[0] as String, w[1] as String)],
        ],
    ]);
  }
}

/// The words of a verse as they are counted for word-by-word data: tokens
/// that contain at least one letter (stand-alone waqf signs are skipped).
List<String> verseWords(String text) => [for (final t in text.split(' ')) if (_hasLetter(t)) t];

bool _hasLetter(String t) => t.runes.any(isArabicLetter);

/// Arabic base letters (not marks, not Quranic annotation signs).
bool isArabicLetter(int c) =>
    (c >= 0x0621 && c <= 0x063A) || (c >= 0x0641 && c <= 0x064A) || c == 0x0671 || (c >= 0x06A9 && c <= 0x06D3 && c != 0x06D4);
