import '../core/utils/hijri.dart';
import 'occasions.dart';

enum ReminderKind { kahf, fastMonThu, fastWhite, salawat }

class PlannedReminder {
  const PlannedReminder(this.kind, this.at, {this.weekday});
  final ReminderKind kind;
  final DateTime at;

  /// For fasting reminders: the weekday of the day to be fasted.
  final int? weekday;
}

/// Hijri days on which voluntary fasting is not allowed (the two Eids and
/// the days of Tashriq) and the whole of Ramadan, where it is obligatory.
bool _noVoluntaryFast(HijriDate h) =>
    h.month == 9 || (h.month == 10 && h.day == 1) || (h.month == 12 && h.day >= 10 && h.day <= 13);

/// Which voluntary-fast reminder (if any) applies to the eve of [fastDay].
({bool monThu, bool white})? fastingFor(DateTime fastDay, {int offsetDays = 0}) {
  final h = HijriDate.fromGregorian(fastDay, offsetDays: offsetDays);
  if (_noVoluntaryFast(h)) return null;
  final monThu = isSunnahFastWeekday(fastDay);
  final white = isWhiteDay(h);
  return (monThu || white) ? (monThu: monThu, white: white) : null;
}

class ReminderPrefs {
  const ReminderPrefs({this.kahf = false, this.fastMonThu = false, this.fastWhite = false, this.salawat = false, this.salawatHour = 17});
  final bool kahf;
  final bool fastMonThu;
  final bool fastWhite;
  final bool salawat;
  final int salawatHour;
}

const kahfHour = 8;
const fastEveHour = 20;

/// Reminders to schedule for the next [days] days starting at [now].
///
/// Pure so it can be tested without notifications: the Friday reminder at
/// [kahfHour], an evening note before each Monday/Thursday and white day,
/// and an optional daily reminder to send blessings on the Prophet ﷺ.
List<PlannedReminder> planReminders(ReminderPrefs p, DateTime now, {int days = 14, int hijriOffset = 0}) {
  final out = <PlannedReminder>[];
  for (var d = 0; d < days; d++) {
    final day = DateTime(now.year, now.month, now.day).add(Duration(days: d));
    if (p.kahf && day.weekday == DateTime.friday) {
      out.add(PlannedReminder(ReminderKind.kahf, day.add(const Duration(hours: kahfHour))));
    }
    if (p.fastMonThu || p.fastWhite) {
      final tomorrow = day.add(const Duration(days: 1));
      final f = fastingFor(tomorrow, offsetDays: hijriOffset);
      if (f != null) {
        // One note per eve; white days take the headline when both apply.
        final kind = f.white && p.fastWhite
            ? ReminderKind.fastWhite
            : (f.monThu && p.fastMonThu ? ReminderKind.fastMonThu : null);
        if (kind != null) {
          out.add(PlannedReminder(kind, day.add(const Duration(hours: fastEveHour)), weekday: tomorrow.weekday));
        }
      }
    }
    if (p.salawat) out.add(PlannedReminder(ReminderKind.salawat, day.add(Duration(hours: p.salawatHour))));
  }
  return [for (final r in out) if (r.at.isAfter(now)) r];
}
