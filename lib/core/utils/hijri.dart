import 'package:hijri/hijri_calendar.dart';

/// Hijri date. Uses the official Umm al-Qura tables (package:hijri, BSD-2)
/// and falls back to the tabular Kuwaiti algorithm outside their range.
///
/// Local moon sighting can still differ by a day, so the app exposes a user
/// offset (settings → Hijri adjustment) that is applied before conversion.
class HijriDate {
  const HijriDate(this.year, this.month, this.day);

  final int year;
  final int month;
  final int day;

  static const monthsAr = [
    'محرم', 'صفر', 'ربيع الأول', 'ربيع الآخر', 'جمادى الأولى', 'جمادى الآخرة',
    'رجب', 'شعبان', 'رمضان', 'شوال', 'ذو القعدة', 'ذو الحجة',
  ];
  static const monthsEn = [
    'Muharram', 'Safar', 'Rabiʿ I', 'Rabiʿ II', 'Jumada I', 'Jumada II',
    'Rajab', 'Shaʿban', 'Ramadan', 'Shawwal', 'Dhu al-Qaʿdah', 'Dhu al-Hijjah',
  ];

  String monthName(String lang) => (lang == 'ar' ? monthsAr : monthsEn)[month - 1];

  factory HijriDate.fromGregorian(DateTime date, {int offsetDays = 0}) {
    final d = DateTime.utc(date.year, date.month, date.day).add(Duration(days: offsetDays));
    try {
      final h = HijriCalendar.fromDate(DateTime(d.year, d.month, d.day));
      if (h.hYear > 1300 && h.hMonth >= 1 && h.hMonth <= 12 && h.hDay >= 1 && h.hDay <= 30) {
        return HijriDate(h.hYear, h.hMonth, h.hDay);
      }
    } catch (_) {
      // Outside the Umm al-Qura table: use the arithmetical calendar.
    }
    return HijriDate.tabular(d);
  }

  /// Tabular (Kuwaiti) conversion.
  factory HijriDate.tabular(DateTime date) {
    final d = DateTime.utc(date.year, date.month, date.day);
    final jd = _julianDay(d.year, d.month, d.day);
    final l0 = jd - 1948440 + 10632;
    final n = (l0 - 1) ~/ 10631;
    final l1 = l0 - 10631 * n + 354;
    final j = ((10985 - l1) ~/ 5316) * ((50 * l1) ~/ 17719) +
        (l1 ~/ 5670) * ((43 * l1) ~/ 15238);
    final l2 = l1 -
        ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
        (j ~/ 16) * ((15238 * j) ~/ 43) +
        29;
    final month = (24 * l2) ~/ 709;
    final day = l2 - (709 * month) ~/ 24;
    final year = 30 * n + j - 30;
    return HijriDate(year, month, day);
  }

  /// Days from [from] until the next occurrence of [month]/[day].
  static int daysUntil(int month, int day, {DateTime? from, int offsetDays = 0}) {
    final start = from ?? DateTime.now();
    for (var i = 0; i < 400; i++) {
      final h = HijriDate.fromGregorian(start.add(Duration(days: i)), offsetDays: offsetDays);
      if (h.month == month && h.day == day) return i;
    }
    return -1;
  }

  static int _julianDay(int y, int m, int d) {
    final a = (14 - m) ~/ 12;
    final yy = y + 4800 - a;
    final mm = m + 12 * a - 3;
    return d + (153 * mm + 2) ~/ 5 + 365 * yy + yy ~/ 4 - yy ~/ 100 + yy ~/ 400 - 32045;
  }

  @override
  bool operator ==(Object other) =>
      other is HijriDate && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => '$year-$month-$day';
}
