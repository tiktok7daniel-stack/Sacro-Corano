import '../core/utils/arabic.dart';
import 'quran_models.dart';

enum SearchMode { phrase, allWords, anyWord }

enum SearchScope { quran, translation }

class SearchFilter {
  const SearchFilter({this.fromSurah = 1, this.toSurah = 114, this.revelation, this.juz});

  final int fromSurah;
  final int toSurah;

  /// null = both, true = Meccan only, false = Medinan only.
  final bool? revelation;
  final int? juz;
}

class SearchHit {
  const SearchHit(this.ref, this.score);
  final AyahRef ref;
  final int score;
}

/// In-memory Quran search. Works on normalised Arabic (both dagger-alef
/// variants) so users can type everyday spelling and still find Uthmani text.
class SearchEngine {
  SearchEngine({
    required this.refs,
    required this.arabicIndex,
    required this.isMeccan,
    required this.juzOf,
  });

  /// refs[i] is the address of entry i of the index.
  final List<AyahRef> refs;
  final List<List<String>> arabicIndex;
  final bool Function(int surah) isMeccan;
  final int Function(AyahRef) juzOf;

  List<SearchHit> search(
    String query, {
    SearchMode mode = SearchMode.allWords,
    SearchFilter filter = const SearchFilter(),
    SearchScope scope = SearchScope.quran,
    Translation? translation,
    int limit = 500,
  }) {
    final q = query.trim();
    if (q.isEmpty) return const [];
    final arabicQuery = isArabic(q);
    final useTranslation = scope == SearchScope.translation || (!arabicQuery && translation != null);
    final needle = useTranslation ? q.toLowerCase() : normalizeArabic(q);
    if (needle.isEmpty) return const [];
    final words = needle.split(' ').where((w) => w.isNotEmpty).toList();

    final hits = <SearchHit>[];
    for (var i = 0; i < refs.length; i++) {
      final r = refs[i];
      if (r.surah < filter.fromSurah || r.surah > filter.toSurah) continue;
      if (filter.revelation != null && isMeccan(r.surah) != filter.revelation) continue;
      if (filter.juz != null && juzOf(r) != filter.juz) continue;

      final haystacks = useTranslation
          ? [translation!.of(r.surah, r.ayah).toLowerCase()]
          : arabicIndex[i];
      var best = 0;
      for (final h in haystacks) {
        final s = _score(h, needle, words, mode);
        if (s > best) best = s;
      }
      if (best > 0) {
        hits.add(SearchHit(r, best));
        if (hits.length >= limit) break;
      }
    }
    hits.sort((a, b) => b.score != a.score ? b.score.compareTo(a.score) : a.ref.compareTo(b.ref));
    return hits;
  }

  static int _score(String hay, String needle, List<String> words, SearchMode mode) {
    switch (mode) {
      case SearchMode.phrase:
        return hay.contains(needle) ? 3 : 0;
      case SearchMode.allWords:
        if (!words.every(hay.contains)) return 0;
        return hay.contains(needle) ? 3 : 2;
      case SearchMode.anyWord:
        final n = words.where(hay.contains).length;
        if (n == 0) return 0;
        return hay.contains(needle) ? words.length + 1 : n;
    }
  }
}
