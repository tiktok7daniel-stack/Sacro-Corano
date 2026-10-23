import '../core/utils/arabic.dart';

/// How one expected word fared against what the recogniser heard.
enum WordState { correct, wrong, missing, pending }

/// One word of the verse: the Uthmani form to display and its loose form.
class ExpectedWord {
  const ExpectedWord(this.display, this.key);
  final String display;
  final String key;
}

/// Splits Uthmani [text] into words, dropping bare stop signs that have no
/// letters of their own.
List<ExpectedWord> expectedWords(String text) => [
      for (final w in text.split(RegExp(r'\s+')))
        if (normalizeArabic(w).isNotEmpty) ExpectedWord(w, normalizeArabic(w)),
    ];

class RecitationResult {
  const RecitationResult(this.states);
  final List<WordState> states;

  int get correct => states.where((s) => s == WordState.correct).length;
  int get wrong => states.where((s) => s == WordState.wrong).length;
  int get missing => states.where((s) => s == WordState.missing).length;
  int get pending => states.where((s) => s == WordState.pending).length;

  /// Share of the verse recited correctly (0..1).
  double get accuracy => states.isEmpty ? 0 : correct / states.length;

  bool get perfect => states.isNotEmpty && correct == states.length;
}

/// Letter-level similarity of two words (1 = identical).
double wordSimilarity(String a, String b) {
  if (a == b) return 1;
  final longest = a.length > b.length ? a.length : b.length;
  if (longest == 0) return 1;
  return 1 - _levenshtein(a, b) / longest;
}

int _levenshtein(String a, String b) {
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final best = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y);
      cur[j] = best;
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Words closer than this count as the same word: speech engines rarely
/// reproduce Quranic spelling exactly (الرحمن / الرحمان).
const matchThreshold = 0.7;

/// Aligns what was [spoken] against the [expected] words.
///
/// While the reciter is still going ([finished] false) words after the last
/// one heard stay [WordState.pending]; once finished they are `missing`.
/// This is an assistive check on top of a general Arabic speech recogniser,
/// not a tajweed judge: it catches skipped, swapped and mispronounced words.
RecitationResult compareRecitation(List<ExpectedWord> expected, String spoken, {bool finished = false}) {
  final heard = normalizeArabic(spoken).split(' ').where((w) => w.isNotEmpty).toList();
  final n = expected.length, m = heard.length;
  if (m == 0) {
    return RecitationResult(List.filled(n, finished ? WordState.missing : WordState.pending));
  }
  // Global alignment: cost 0 for a match, 1 for substitution/insert/delete.
  final cost = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = 1; i <= n; i++) {
    cost[i][0] = i;
  }
  for (var j = 1; j <= m; j++) {
    cost[0][j] = j;
  }
  bool same(int i, int j) => wordSimilarity(expected[i].key, heard[j]) >= matchThreshold;
  for (var i = 1; i <= n; i++) {
    for (var j = 1; j <= m; j++) {
      final diag = cost[i - 1][j - 1] + (same(i - 1, j - 1) ? 0 : 1);
      final up = cost[i - 1][j] + 1;
      final left = cost[i][j - 1] + 1;
      cost[i][j] = [diag, up, left].reduce((x, y) => x < y ? x : y);
    }
  }
  final states = List<WordState>.filled(n, WordState.missing);
  var i = n, j = m;
  while (i > 0 && j > 0) {
    final isSame = same(i - 1, j - 1);
    if (cost[i][j] == cost[i - 1][j - 1] + (isSame ? 0 : 1)) {
      states[i - 1] = isSame ? WordState.correct : WordState.wrong;
      i--;
      j--;
    } else if (cost[i][j] == cost[i - 1][j] + 1) {
      states[--i] = WordState.missing;
    } else {
      j--;
    }
  }
  while (i > 0) {
    states[--i] = WordState.missing;
  }
  if (!finished) {
    // Everything after the last word that was heard is still to come.
    var last = -1;
    for (var k = 0; k < n; k++) {
      if (states[k] != WordState.missing) last = k;
    }
    for (var k = last + 1; k < n; k++) {
      states[k] = WordState.pending;
    }
  }
  return RecitationResult(states);
}
