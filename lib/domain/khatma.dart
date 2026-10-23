import 'package:flutter/foundation.dart';

/// An adaptive Quran completion plan, tracked in mushaf pages (1..604).
///
/// The daily target is not fixed: it is recomputed every day from what is
/// left and how many days remain, so missed days are absorbed gradually and
/// reading ahead lightens the following days. [busyWeekdays] lets the user
/// mark days (e.g. Friday) that should carry a lighter load.
@immutable
class KhatmaPlan {
  const KhatmaPlan({
    required this.start,
    required this.targetDays,
    this.pagesRead = 0,
    this.log = const {},
    this.busyWeekdays = const {},
    this.completedCount = 0,
  });

  final DateTime start;
  final int targetDays;

  /// Highest page completed (pages are read in order).
  final int pagesRead;

  /// yyyy-mm-dd → pages read that day.
  final Map<String, int> log;

  /// DateTime.weekday values (1 = Monday) that get half load.
  final Set<int> busyWeekdays;
  final int completedCount;

  static const totalPages = 604;

  DateTime get end => DateTime(start.year, start.month, start.day).add(Duration(days: targetDays - 1));
  int get remainingPages => totalPages - pagesRead;
  double get progress => pagesRead / totalPages;
  bool get done => pagesRead >= totalPages;

  int daysLeft(DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final d = end.difference(today).inDays + 1;
    return d < 1 ? 1 : d;
  }

  double _weight(int weekday) => busyWeekdays.contains(weekday) ? 0.5 : 1.0;

  /// Pages to read today so the plan still ends on time.
  int todayTarget(DateTime now) {
    if (done) return 0;
    final today = DateTime(now.year, now.month, now.day);
    final readToday = log[dayKey(today)] ?? 0;
    final left = remainingPages + readToday;
    final days = daysLeft(now);
    var totalWeight = 0.0;
    for (var i = 0; i < days; i++) {
      totalWeight += _weight(today.add(Duration(days: i)).weekday);
    }
    final share = left * _weight(today.weekday) / totalWeight;
    return share.ceil().clamp(1, left);
  }

  int readOn(DateTime day) => log[dayKey(day)] ?? 0;

  /// Expected pages completed by end of [now] on an even schedule.
  int expectedBy(DateTime now) {
    final elapsed = DateTime(now.year, now.month, now.day).difference(DateTime(start.year, start.month, start.day)).inDays + 1;
    return (totalPages * elapsed / targetDays).clamp(0, totalPages).round();
  }

  /// Positive = ahead of schedule, negative = behind (in pages).
  int scheduleDelta(DateTime now) => pagesRead - expectedBy(now);

  KhatmaPlan markRead(int uptoPage, DateTime now) {
    final page = uptoPage.clamp(0, totalPages);
    if (page <= pagesRead) return this;
    final k = dayKey(now);
    final newLog = Map<String, int>.from(log)..[k] = (log[k] ?? 0) + (page - pagesRead);
    return copyWith(pagesRead: page, log: newLog);
  }

  KhatmaPlan restart(DateTime now) => KhatmaPlan(
        start: DateTime(now.year, now.month, now.day),
        targetDays: targetDays,
        busyWeekdays: busyWeekdays,
        completedCount: completedCount + (done ? 1 : 0),
      );

  KhatmaPlan copyWith({int? pagesRead, Map<String, int>? log, Set<int>? busyWeekdays, int? targetDays}) => KhatmaPlan(
        start: start,
        targetDays: targetDays ?? this.targetDays,
        pagesRead: pagesRead ?? this.pagesRead,
        log: log ?? this.log,
        busyWeekdays: busyWeekdays ?? this.busyWeekdays,
        completedCount: completedCount,
      );

  Map<String, dynamic> toJson() => {
        'start': start.toIso8601String(),
        'days': targetDays,
        'read': pagesRead,
        'log': log,
        'busy': busyWeekdays.toList(),
        'done': completedCount,
      };

  factory KhatmaPlan.fromJson(Map<String, dynamic> j) => KhatmaPlan(
        start: DateTime.parse(j['start'] as String),
        targetDays: j['days'] as int,
        pagesRead: j['read'] as int? ?? 0,
        log: (j['log'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
        busyWeekdays: ((j['busy'] as List?) ?? []).cast<int>().toSet(),
        completedCount: j['done'] as int? ?? 0,
      );
}

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Length of the run of consecutive active days ending today (or yesterday,
/// so a streak is not "lost" before the user had a chance to act today).
int currentStreak(Set<String> activeDays, DateTime now) {
  var d = DateTime(now.year, now.month, now.day);
  if (!activeDays.contains(dayKey(d))) d = d.subtract(const Duration(days: 1));
  var n = 0;
  while (activeDays.contains(dayKey(d))) {
    n++;
    d = d.subtract(const Duration(days: 1));
  }
  return n;
}

int longestStreak(Set<String> activeDays) {
  if (activeDays.isEmpty) return 0;
  final days = activeDays.map((s) => DateTime.parse('${s}T00:00:00Z')).toList()..sort();
  var best = 1, cur = 1;
  for (var i = 1; i < days.length; i++) {
    final gap = days[i].difference(days[i - 1]).inDays;
    if (gap == 1) {
      cur++;
      if (cur > best) best = cur;
    } else if (gap > 1) {
      cur = 1;
    }
  }
  return best;
}
