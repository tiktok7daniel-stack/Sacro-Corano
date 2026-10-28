import 'dart:convert';
import 'dart:io' show gzip;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../core/utils/arabic.dart';
import '../../domain/quran_models.dart';

/// The full mushaf text plus Hafs structural metadata, held in memory.
///
/// 6236 short strings take ~3 MB of heap, which is far cheaper than hitting a
/// database for every scroll frame, and keeps the reader fully offline.
class QuranData {
  QuranData._({
    required this.surahs,
    required this._text,
    required this._pageStarts,
    required this._juzStarts,
    required this._rubStarts,
    required Set<int> sajdaIndexes,
    required this.textSource,
  })  : _sajda = sajdaIndexes;

  final List<SurahInfo> surahs;
  final List<List<String>> _text;
  final List<int> _pageStarts;
  final List<int> _juzStarts;
  final List<int> _rubStarts;
  final Set<int> _sajda;
  final String textSource;
  late final List<int> _surahStarts = [for (final s in surahs) s.startIndex];

  static const totalAyahs = 6236;
  static const totalPages = 604;

  static Future<QuranData> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    final metaRaw = await b.loadString('assets/data/meta.json');
    final textGz = await b.load('assets/data/quran_uthmani.json.gz');
    return compute(_parse, (metaRaw, textGz.buffer.asUint8List()));
  }

  /// Test helper that skips the asset bundle.
  @visibleForTesting
  static QuranData fromRaw(String metaJson, Uint8List textGz) => _parse((metaJson, textGz));

  /// The text writes the open (mutatabi') tanween with the positional code
  /// points of the KFGQPC fonts (U+0657, U+065E, U+0656). Amiri Quran draws
  /// those as an inverted damma, nothing and a subscript alef, so they are
  /// swapped for the standard open tanween (U+08F0–U+08F2). One code point
  /// for one, so tajweed offsets and word counts are unchanged.
  static String standardTanween(String s) => s.replaceAll('\u0657', '\u08F0').replaceAll('\u065E', '\u08F1').replaceAll('\u0656', '\u08F2');

  static QuranData _parse((String, Uint8List) input) {
    final meta = jsonDecode(input.$1) as Map<String, dynamic>;
    final textJson = jsonDecode(utf8.decode(gzip.decode(input.$2))) as Map<String, dynamic>;
    List<int> ints(String k) => (meta[k] as List).cast<int>();
    return QuranData._(
      surahs: (meta['surahs'] as List).map((e) => SurahInfo.fromJson(e as Map<String, dynamic>)).toList(),
      text: (textJson['ayahs'] as List).map((s) => (s as List).cast<String>().map(standardTanween).toList()).toList(),
      pageStarts: ints('pages'),
      juzStarts: ints('juz'),
      rubStarts: ints('rub'),
      sajdaIndexes: ints('sajda').toSet(),
      textSource: textJson['source'] as String,
    );
  }

  SurahInfo surah(int n) => surahs[n - 1];

  String text(int surah, int ayah) => _text[surah - 1][ayah - 1];
  String textOf(AyahRef r) => text(r.surah, r.ayah);

  /// 1-based absolute index (1..6236).
  int absoluteIndex(int surah, int ayah) => surahs[surah - 1].startIndex + ayah - 1;

  AyahRef refAt(int absolute) {
    final i = _upperBound(_surahStarts, absolute) - 1;
    final s = surahs[i];
    return AyahRef(s.number, absolute - s.startIndex + 1);
  }

  int pageOf(int surah, int ayah) => _upperBound(_pageStarts, absoluteIndex(surah, ayah));
  int juzOf(int surah, int ayah) => _upperBound(_juzStarts, absoluteIndex(surah, ayah));

  /// 1..240 quarter of hizb.
  int rubOf(int surah, int ayah) => _upperBound(_rubStarts, absoluteIndex(surah, ayah));
  int hizbOf(int surah, int ayah) => (rubOf(surah, ayah) - 1) ~/ 4 + 1;

  bool isSajda(int surah, int ayah) => _sajda.contains(absoluteIndex(surah, ayah));

  /// True when [ayah] starts a new quarter-hizb (shown as ۞ in the margin).
  bool startsRub(int surah, int ayah) {
    final idx = absoluteIndex(surah, ayah);
    final r = rubOf(surah, ayah);
    return _rubStarts[r - 1] == idx;
  }

  /// All verses on mushaf page [page] (1..604).
  List<AyahRef> ayahsOnPage(int page) {
    final start = _pageStarts[page - 1];
    final end = page < totalPages ? _pageStarts[page] - 1 : totalAyahs;
    return [for (var i = start; i <= end; i++) refAt(i)];
  }

  AyahRef juzStart(int juz) => refAt(_juzStarts[juz - 1]);
  AyahRef rubStart(int rub) => refAt(_rubStarts[rub - 1]);

  int firstPageOfSurah(int surah) => pageOf(surah, 1);

  /// Number of verses between two refs, inclusive.
  int countBetween(AyahRef a, AyahRef b) =>
      (absoluteIndex(b.surah, b.ayah) - absoluteIndex(a.surah, a.ayah)).abs() + 1;

  /// Builds normalised copies of the text for search (two variants each, see
  /// [normalizeArabic]). Run in an isolate; takes ~150 ms on a mid phone.
  static List<List<String>> buildSearchIndex(List<List<String>> text) => [
        for (final s in text)
          for (final a in s) [normalizeArabic(a), normalizeArabic(a, daggerAsAlef: true)],
      ];

  List<List<String>> get rawText => _text;

  /// Largest i such that list[i-1] <= value, i.e. 1-based bucket of [value].
  static int _upperBound(List<int> list, int value) {
    var lo = 0, hi = list.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (list[mid] <= value) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return lo;
  }
}
