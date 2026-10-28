import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/l10n/strings.dart';
import '../../../core/theme/brand.dart';
import '../../../data/quran/word_data.dart';

/// Colours of the tajweed classes, tuned for dark and light pages. They
/// follow the usual colour-coded mushaf: reds for the madd lengths, green
/// for ghunnah, grey for letters merged away, blue for qalqalah.
Map<String, Color> tajweedColors({required bool dark}) => dark
    ? const {
        'madd_lazim': Color(0xFFFF6B6B),
        'madd_wajib': Color(0xFFFF8A80),
        'madd_jaiz': Color(0xFFFFB74D),
        'ghunnah': Color(0xFF69DB7C),
        'silent': Color(0xFF8D99A6),
        'qalqalah': Color(0xFF74C0FC),
        'tafkheem': Color(0xFF9FA8FF),
      }
    : const {
        'madd_lazim': Color(0xFFB71C1C),
        'madd_wajib': Color(0xFFE53935),
        'madd_jaiz': Color(0xFFEF6C00),
        'ghunnah': Color(0xFF2E7D32),
        'silent': Color(0xFF9E9E9E),
        'qalqalah': Color(0xFF1565C0),
        'tafkheem': Color(0xFF283593),
      };

const tajweedClassOrder = ['madd_lazim', 'madd_wajib', 'madd_jaiz', 'ghunnah', 'silent', 'qalqalah', 'tafkheem'];

/// Builds the spans of one verse: colour runs from [runs] (flat
/// `[start, end, classIndex, …]` in code points) and `۞` dropped without
/// shifting the offsets. Gestures go on the leaf spans (a recognizer on a
/// parent span does not reach its children): words answer a long press
/// when [onWordLongPress] is set, otherwise every leaf gets [tap].
List<InlineSpan> verseSpans(
  String text, {
  List<int> runs = const [],
  List<String> classes = const [],
  Map<String, Color> colors = const {},
  void Function(int wordIndex)? onWordLongPress,
  GestureRecognizer? tap,
  List<GestureRecognizer>? recognizers,
}) {
  final cps = text.runes.toList();
  final cls = List<int>.filled(cps.length, -1);
  for (var i = 0; i + 2 < runs.length; i += 3) {
    for (var k = runs[i]; k < runs[i + 1] && k < cps.length; k++) {
      cls[k] = runs[i + 2];
    }
  }
  Color? colorOf(int c) => c < 0 || c >= classes.length ? null : colors[classes[c]];

  final out = <InlineSpan>[];
  var word = 0;
  var i = 0;
  while (i < cps.length) {
    // One token (a word or a stand-alone sign).
    var j = i;
    while (j < cps.length && cps[j] != 0x20) {
      j++;
    }
    final isWord = cps.sublist(i, j).any(isArabicLetter);
    var rec = tap;
    if (isWord && onWordLongPress != null) {
      final index = word;
      final r = LongPressGestureRecognizer()..onLongPress = () => onWordLongPress(index);
      recognizers?.add(r);
      rec = r;
    }
    var k = i;
    while (k < j) {
      var e = k;
      while (e < j && cls[e] == cls[k]) {
        e++;
      }
      final chunk = String.fromCharCodes(cps.sublist(k, e).where((c) => c != 0x06DE));
      if (chunk.isNotEmpty) {
        final color = colorOf(cls[k]);
        out.add(TextSpan(text: chunk, style: color == null ? null : TextStyle(color: color), recognizer: rec));
      }
      k = e;
    }
    if (j < cps.length) out.add(TextSpan(text: ' ', recognizer: tap));
    if (isWord) word++;
    i = j + 1;
  }
  return out;
}

/// The words of a verse (as counted by [verseWords]), each as coloured
/// spans; stand-alone signs stay with the word before them.
List<List<InlineSpan>> wordSpanLists(
  String text, {
  List<int> runs = const [],
  List<String> classes = const [],
  Map<String, Color> colors = const {},
}) {
  final cps = text.runes.toList();
  final cls = List<int>.filled(cps.length, -1);
  for (var i = 0; i + 2 < runs.length; i += 3) {
    for (var k = runs[i]; k < runs[i + 1] && k < cps.length; k++) {
      cls[k] = runs[i + 2];
    }
  }
  Color? colorOf(int c) => c < 0 || c >= classes.length ? null : colors[classes[c]];
  final out = <List<InlineSpan>>[];
  var i = 0;
  while (i < cps.length) {
    var j = i;
    while (j < cps.length && cps[j] != 0x20) {
      j++;
    }
    final pieces = <InlineSpan>[];
    var k = i;
    while (k < j) {
      var e = k;
      while (e < j && cls[e] == cls[k]) {
        e++;
      }
      final chunk = String.fromCharCodes(cps.sublist(k, e).where((c) => c != 0x06DE));
      if (chunk.isNotEmpty) {
        final color = colorOf(cls[k]);
        pieces.add(TextSpan(text: chunk, style: color == null ? null : TextStyle(color: color)));
      }
      k = e;
    }
    if (cps.sublist(i, j).any(isArabicLetter)) {
      out.add(pieces);
    } else if (pieces.isNotEmpty && out.isNotEmpty) {
      out.last.addAll([const TextSpan(text: ' '), ...pieces]);
    }
    i = j + 1;
  }
  return out;
}

/// Legend of the tajweed colours.
class TajweedLegend extends StatelessWidget {
  const TajweedLegend({super.key, required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final colors = tajweedColors(dark: dark);
    return Wrap(spacing: 14, runSpacing: 8, children: [
      for (final c in tajweedClassOrder)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: colors[c], shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(context.tr('tj_$c'), style: const TextStyle(fontSize: 13)),
        ]),
    ]);
  }
}

Future<void> showTajweedLegend(BuildContext context, {required bool dark}) => showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(context.tr('tajweed_colors'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TajweedLegend(dark: dark),
            const SizedBox(height: 14),
            Text(context.tr('tajweed_note'), style: const TextStyle(color: Brand.textMid, fontSize: 12, height: 1.5)),
          ]),
        ),
      ),
    );
