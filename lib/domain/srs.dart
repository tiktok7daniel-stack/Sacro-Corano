import 'package:flutter/foundation.dart';

/// A memorisation unit (a range of verses) scheduled with SM-2.
@immutable
class HifzCard {
  const HifzCard({
    required this.id,
    required this.surah,
    required this.from,
    required this.to,
    this.easiness = 2.5,
    this.interval = 0,
    this.repetitions = 0,
    required this.due,
    this.mistakes = 0,
    this.reviews = 0,
    this.lastGrade,
  });

  final String id;
  final int surah;
  final int from;
  final int to;
  final double easiness;

  /// Days until the next review.
  final int interval;
  final int repetitions;
  final DateTime due;
  final int mistakes;
  final int reviews;
  final int? lastGrade;

  bool isDue(DateTime now) => !due.isAfter(DateTime(now.year, now.month, now.day, 23, 59, 59));

  /// 0 = new, 1 = learning, 2 = young, 3 = mature (interval ≥ 21 days).
  int get stage => reviews == 0 ? 0 : (interval < 3 ? 1 : (interval < 21 ? 2 : 3));

  HifzCard copyWith({
    double? easiness,
    int? interval,
    int? repetitions,
    DateTime? due,
    int? mistakes,
    int? reviews,
    int? lastGrade,
  }) =>
      HifzCard(
        id: id,
        surah: surah,
        from: from,
        to: to,
        easiness: easiness ?? this.easiness,
        interval: interval ?? this.interval,
        repetitions: repetitions ?? this.repetitions,
        due: due ?? this.due,
        mistakes: mistakes ?? this.mistakes,
        reviews: reviews ?? this.reviews,
        lastGrade: lastGrade ?? this.lastGrade,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        's': surah,
        'f': from,
        't': to,
        'e': easiness,
        'i': interval,
        'r': repetitions,
        'd': due.toIso8601String(),
        'm': mistakes,
        'n': reviews,
        'g': lastGrade,
      };

  factory HifzCard.fromJson(Map<String, dynamic> j) => HifzCard(
        id: j['id'] as String,
        surah: j['s'] as int,
        from: j['f'] as int,
        to: j['t'] as int,
        easiness: (j['e'] as num).toDouble(),
        interval: j['i'] as int,
        repetitions: j['r'] as int,
        due: DateTime.parse(j['d'] as String),
        mistakes: j['m'] as int? ?? 0,
        reviews: j['n'] as int? ?? 0,
        lastGrade: j['g'] as int?,
      );
}

/// SuperMemo-2 scheduling (Wozniak, 1990).
///
/// [grade] 0..5 where 5 = perfect recall, 3 = recalled with effort,
/// below 3 = forgotten (card restarts). [mistakes] are the slips the reciter
/// marked during the test and are tracked separately for the statistics.
HifzCard reviewCard(HifzCard c, int grade, {required DateTime now, int mistakes = 0}) {
  assert(grade >= 0 && grade <= 5);
  final q = grade.clamp(0, 5);
  var ef = c.easiness + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02));
  if (ef < 1.3) ef = 1.3;

  int reps;
  int interval;
  if (q < 3) {
    reps = 0;
    interval = 1;
  } else {
    reps = c.repetitions + 1;
    interval = switch (reps) {
      1 => 1,
      2 => 6,
      _ => (c.interval * ef).round(),
    };
  }
  final today = DateTime(now.year, now.month, now.day);
  return c.copyWith(
    easiness: double.parse(ef.toStringAsFixed(3)),
    interval: interval,
    repetitions: reps,
    due: today.add(Duration(days: interval)),
    mistakes: c.mistakes + mistakes,
    reviews: c.reviews + 1,
    lastGrade: q,
  );
}

/// Splits a surah into memorisation chunks of roughly [size] verses.
List<(int, int)> chunkSurah(int ayahCount, {int size = 5}) {
  final out = <(int, int)>[];
  for (var a = 1; a <= ayahCount; a += size) {
    final end = (a + size - 1).clamp(1, ayahCount);
    out.add((a, end));
  }
  // Avoid a dangling 1–2 verse chunk at the end.
  if (out.length > 1 && out.last.$2 - out.last.$1 < 2) {
    final last = out.removeLast();
    final prev = out.removeLast();
    out.add((prev.$1, last.$2));
  }
  return out;
}
