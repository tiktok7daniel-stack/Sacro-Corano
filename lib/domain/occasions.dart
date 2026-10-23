import '../core/utils/hijri.dart';

/// Hijri occasions shown on the calendar and the home countdown.
class Occasion {
  const Occasion(this.id, this.month, this.day, this.nameAr, this.nameEn, {this.days = 1});
  final String id;
  final int month;
  final int day;
  final String nameAr;
  final String nameEn;

  /// Length in days (e.g. Ramadan, the days of Tashriq).
  final int days;

  String name(String lang) => lang == 'ar' ? nameAr : nameEn;

  bool covers(HijriDate h) => h.month == month && h.day >= day && h.day < day + days;
}

const occasions = <Occasion>[
  Occasion('hijri_new_year', 1, 1, 'رأس السنة الهجرية', 'Islamic New Year'),
  Occasion('ashura', 1, 10, 'يوم عاشوراء', 'Day of Ashura'),
  Occasion('isra', 7, 27, 'الإسراء والمعراج (على المشهور)', 'Isra and Miʿraj (commonly observed)'),
  Occasion('ramadan', 9, 1, 'شهر رمضان', 'Ramadan', days: 30),
  Occasion('last_ten', 9, 21, 'العشر الأواخر', 'Last ten nights', days: 10),
  Occasion('eid_fitr', 10, 1, 'عيد الفطر', 'Eid al-Fitr'),
  Occasion('dhul_hijja_ten', 12, 1, 'العشر من ذي الحجة', 'First ten of Dhul-Hijjah', days: 9),
  Occasion('arafah', 12, 9, 'يوم عرفة', 'Day of Arafah'),
  Occasion('eid_adha', 12, 10, 'عيد الأضحى', 'Eid al-Adha'),
  Occasion('tashriq', 12, 11, 'أيام التشريق', 'Days of Tashriq', days: 3),
];

/// Recommended voluntary fasts: the white days (13–15) and Mon/Thu.
bool isWhiteDay(HijriDate h) => h.day >= 13 && h.day <= 15 && h.month != 9;
bool isSunnahFastWeekday(DateTime d) => d.weekday == DateTime.monday || d.weekday == DateTime.thursday;

/// Occasions falling on [date].
List<Occasion> occasionsOn(DateTime date, {int offsetDays = 0}) {
  final h = HijriDate.fromGregorian(date, offsetDays: offsetDays);
  return [
    for (final o in occasions)
      if (o.covers(h)) o,
  ];
}

/// The next occasion starting after (or on) [from], with days until it.
(Occasion, int) nextOccasion(DateTime from, {int offsetDays = 0, Set<String> only = const {}}) {
  for (var i = 0; i < 400; i++) {
    final d = from.add(Duration(days: i));
    final h = HijriDate.fromGregorian(d, offsetDays: offsetDays);
    for (final o in occasions) {
      if (only.isNotEmpty && !only.contains(o.id)) continue;
      if (o.month == h.month && o.day == h.day) return (o, i);
    }
  }
  return (occasions.first, -1);
}
