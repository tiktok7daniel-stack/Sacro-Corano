import 'package:flutter/foundation.dart';
import 'package:hijri/hijri_calendar.dart';

import '../core/utils/hijri.dart';

/// Where [day] falls in Ramadan: its 1-based day number and the Hijri year,
/// or null outside the month.
({int year, int day})? ramadanDay(DateTime day, {int offsetDays = 0}) {
  final h = HijriDate.fromGregorian(day, offsetDays: offsetDays);
  return h.month == 9 ? (year: h.year, day: h.day) : null;
}

/// Days until the first of Ramadan (0 when it is today or already running).
int daysUntilRamadan(DateTime from, {int offsetDays = 0}) {
  final start = DateTime(from.year, from.month, from.day);
  for (var i = 0; i < 400; i++) {
    final h = HijriDate.fromGregorian(start.add(Duration(days: i)), offsetDays: offsetDays);
    if (h.month == 9) return i;
  }
  return 400;
}

/// Length of Ramadan in [hijriYear] (29 or 30 days).
int ramadanLength(int hijriYear) {
  try {
    final n = HijriCalendar().getDaysInMonth(hijriYear, 9);
    if (n == 29 || n == 30) return n;
  } catch (_) {}
  return 30;
}

/// The juz to read on Ramadan [day] so the khatma ends with the month:
/// one a day in a 30-day month, with the last day taking two in a 29-day one.
({int from, int to}) juzForRamadanDay(int day, {int length = 30}) {
  final d = day.clamp(1, length);
  final from = ((d - 1) * 30) ~/ length + 1;
  final to = (d * 30) ~/ length;
  return (from: from, to: to < from ? from : to);
}

/// Fasting log and make-up (qada) count. Ramadan days are keyed `year-day`.
@immutable
class FastingLedger {
  const FastingLedger({this.days = const {}, this.qadaOwedExtra = 0, this.qadaDone = 0});

  /// 'f' fasted, 'm' missed.
  final Map<String, String> days;

  /// Days owed from before the app (entered by the user).
  final int qadaOwedExtra;
  final int qadaDone;

  static String key(int year, int day) => '$year-$day';

  int fasted(int year) => days.entries.where((e) => e.key.startsWith('$year-') && e.value == 'f').length;
  int missed(int year) => days.entries.where((e) => e.key.startsWith('$year-') && e.value == 'm').length;

  int get totalMissed => days.values.where((v) => v == 'm').length;
  int get qadaOwed => totalMissed + qadaOwedExtra;
  int get qadaRemaining => (qadaOwed - qadaDone).clamp(0, 100000);

  FastingLedger mark(int year, int day, String? status) {
    final next = {...days};
    final k = key(year, day);
    status == null ? next.remove(k) : next[k] = status;
    return copyWith(days: next);
  }

  FastingLedger copyWith({Map<String, String>? days, int? qadaOwedExtra, int? qadaDone}) =>
      FastingLedger(days: days ?? this.days, qadaOwedExtra: qadaOwedExtra ?? this.qadaOwedExtra, qadaDone: qadaDone ?? this.qadaDone);

  Map<String, dynamic> toJson() => {'d': days, 'x': qadaOwedExtra, 'q': qadaDone};
  factory FastingLedger.fromJson(Map<String, dynamic> j) => FastingLedger(
        days: j['d'] is Map ? (j['d'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())) : const {},
        qadaOwedExtra: (j['x'] as num?)?.toInt() ?? 0,
        qadaDone: (j['q'] as num?)?.toInt() ?? 0,
      );
}

/// Juz marked as read per Hijri year of Ramadan.
Map<String, List<int>> decodeJuzLog(Map<String, dynamic> m) =>
    {for (final e in m.entries) e.key: ((e.value as List?) ?? []).map((x) => (x as num).toInt()).toList()};
