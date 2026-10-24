import 'dart:math' as math;

/// How a word of the passage stands during a recitation test.
enum WordState { pending, correct, missed }

/// Normalises a Quranic (Uthmani) or everyday Arabic word for comparison
/// with speech-recognition output: no diacritics or Quranic signs, one form
/// for alef / hamza carriers, ta marbuta and alef maqsura.
String normalizeSpoken(String w, {bool daggerAsAlef = false}) {
  final b = StringBuffer();
  for (final c in w.runes) {
    if (c == 0x0670) {
      if (daggerAsAlef) b.writeCharCode(0x0627);
      continue;
    }
    if ((c >= 0x0610 && c <= 0x061A) || (c >= 0x064B && c <= 0x065F) || (c >= 0x06D6 && c <= 0x06ED) || c == 0x0640) continue;
    switch (c) {
      case 0x0671 || 0x0622 || 0x0623 || 0x0625:
        b.writeCharCode(0x0627); // ا
      case 0x0649 || 0x0626:
        b.writeCharCode(0x064A); // ي
      case 0x0629:
        b.writeCharCode(0x0647); // ه
      case 0x0624:
        b.writeCharCode(0x0648); // و
      case 0x0621:
        break; // a bare hamza is often dropped by recognisers
      default:
        if ((c >= 0x0621 && c <= 0x064A) || (c >= 0x0660 && c <= 0x0669)) b.writeCharCode(c);
    }
  }
  return b.toString();
}

int _levenshtein(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      cur[j] = math.min(math.min(cur[j - 1] + 1, prev[j] + 1), prev[j - 1] + cost);
    }
    prev = cur;
  }
  return prev[b.length];
}

/// One expected word in its two normal forms (Uthmani dagger alef dropped
/// or written as a full alef: "الرحمن" and "العالمين" both match).
class ExpectedWord {
  ExpectedWord(this.display) : a = normalizeSpoken(display), b = normalizeSpoken(display, daggerAsAlef: true);
  final String display;
  final String a;
  final String b;
}

bool _close(String spoken, String target) {
  if (spoken.isEmpty || target.isEmpty) return false;
  if (spoken == target) return true;
  final len = math.max(spoken.length, target.length);
  if (len <= 2) return false;
  return 1 - _levenshtein(spoken, target) / len >= 0.72;
}

/// Whether a recognised word matches an expected one.
bool wordsMatch(String spoken, ExpectedWord w) {
  final s = normalizeSpoken(spoken);
  return _close(s, w.a) || _close(s, w.b);
}

/// Aligns the recognised words of a session with the passage. Skipped or
/// wrong words become [WordState.missed] once a later word is recognised;
/// extra words (repetitions, "صدق الله العظيم") are ignored.
class RecitationAlignment {
  RecitationAlignment(this.states, this.position);
  final List<WordState> states;

  /// Index of the next expected word.
  final int position;

  bool get done => position >= states.length;
  int get correct => states.where((s) => s == WordState.correct).length;
  int get missed => states.where((s) => s == WordState.missed).length;
}

RecitationAlignment alignRecitation(List<ExpectedWord> expected, List<String> spoken, {int lookahead = 3}) {
  final states = List<WordState>.filled(expected.length, WordState.pending);
  var p = 0;
  for (var i = 0; i < spoken.length && p < expected.length; i++) {
    final w = spoken[i];
    var hit = -1;
    for (var k = 0; k <= lookahead && p + k < expected.length; k++) {
      if (wordsMatch(w, expected[p + k])) {
        hit = k;
        break;
      }
    }
    if (hit >= 0) {
      for (var k = 0; k < hit; k++) {
        states[p + k] = WordState.missed;
      }
      states[p + hit] = WordState.correct;
      p += hit + 1;
      continue;
    }
    // A recogniser may glue two words ("فيه هدى" → "فيههدى") or split one.
    if (p + 1 < expected.length) {
      final glued = ExpectedWord('${expected[p].display}${expected[p + 1].display}');
      if (wordsMatch(w, glued)) {
        states[p] = WordState.correct;
        states[p + 1] = WordState.correct;
        p += 2;
        continue;
      }
    }
    if (i + 1 < spoken.length && wordsMatch('$w${spoken[i + 1]}', expected[p])) {
      states[p] = WordState.correct;
      p += 1;
      i += 1;
    }
  }
  return RecitationAlignment(states, p);
}
