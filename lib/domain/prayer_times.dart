import 'package:adhan/adhan.dart' as adhan;

import 'settings.dart';

enum PrayerName { fajr, sunrise, dhuhr, asr, maghrib, isha }

extension PrayerNameX on PrayerName {
  bool get isFard => this != PrayerName.sunrise;
}

class PrayerMethodInfo {
  const PrayerMethodInfo(this.id, this.nameAr, this.nameEn);
  final String id;
  final String nameAr;
  final String nameEn;
}

const prayerMethods = [
  PrayerMethodInfo('muslim_world_league', 'رابطة العالم الإسلامي', 'Muslim World League'),
  PrayerMethodInfo('umm_al_qura', 'أم القرى (مكة)', 'Umm al-Qura (Makkah)'),
  PrayerMethodInfo('egyptian', 'الهيئة المصرية العامة للمساحة', 'Egyptian General Authority'),
  PrayerMethodInfo('karachi', 'جامعة العلوم الإسلامية بكراتشي', 'Univ. of Islamic Sciences, Karachi'),
  PrayerMethodInfo('north_america', 'الجمعية الإسلامية لأمريكا الشمالية (ISNA)', 'ISNA (North America)'),
  PrayerMethodInfo('dubai', 'دبي', 'Dubai'),
  PrayerMethodInfo('kuwait', 'الكويت', 'Kuwait'),
  PrayerMethodInfo('qatar', 'قطر', 'Qatar'),
  PrayerMethodInfo('singapore', 'سنغافورة', 'Singapore'),
  PrayerMethodInfo('turkey', 'رئاسة الشؤون الدينية التركية', 'Diyanet (Turkey)'),
  PrayerMethodInfo('tehran', 'معهد الجيوفيزياء – طهران', 'Inst. of Geophysics, Tehran'),
  PrayerMethodInfo('moon_sighting_committee', 'لجنة رؤية الهلال', 'Moonsighting Committee'),
];

/// One day of computed prayer times (local time).
class DayTimes {
  const DayTimes(this.date, this.times);
  final DateTime date;
  final Map<PrayerName, DateTime> times;

  DateTime operator [](PrayerName p) => times[p]!;

  /// The next fard prayer after [now], or null when Isha has passed.
  PrayerName? nextAfter(DateTime now) {
    for (final p in PrayerName.values) {
      if (!p.isFard) continue;
      if (times[p]!.isAfter(now)) return p;
    }
    return null;
  }

  PrayerName? currentAt(DateTime now) {
    PrayerName? cur;
    for (final p in PrayerName.values) {
      if (!times[p]!.isAfter(now)) cur = p;
    }
    return cur;
  }
}

/// Wraps the MIT-licensed `adhan` package (port of batoulapps/adhan).
class PrayerCalculator {
  const PrayerCalculator(this.settings);
  final AppSettings settings;

  adhan.CalculationParameters _params() {
    final method = adhan.CalculationMethod.values.firstWhere(
      (m) => m.name == settings.calcMethod,
      orElse: () => adhan.CalculationMethod.muslim_world_league,
    );
    final p = method.getParameters();
    p.madhab = settings.madhab == 'hanafi' ? adhan.Madhab.hanafi : adhan.Madhab.shafi;
    p.highLatitudeRule = adhan.HighLatitudeRule.values.firstWhere(
      (r) => r.name == settings.highLatRule,
      orElse: () => adhan.HighLatitudeRule.middle_of_the_night,
    );
    final o = settings.prayerOffsets;
    p.adjustments = adhan.PrayerAdjustments(
      fajr: o['fajr'] ?? 0,
      sunrise: o['sunrise'] ?? 0,
      dhuhr: o['dhuhr'] ?? 0,
      asr: o['asr'] ?? 0,
      maghrib: o['maghrib'] ?? 0,
      isha: o['isha'] ?? 0,
    );
    return p;
  }

  DayTimes forDate(DateTime date, {double? lat, double? lng}) {
    final coords = adhan.Coordinates(lat ?? settings.lat!, lng ?? settings.lng!);
    final pt = adhan.PrayerTimes(
      coords,
      adhan.DateComponents(date.year, date.month, date.day),
      _params(),
    );
    final day = DateTime(date.year, date.month, date.day);
    return DayTimes(day, {
      PrayerName.fajr: pt.fajr.toLocal(),
      PrayerName.sunrise: pt.sunrise.toLocal(),
      PrayerName.dhuhr: pt.dhuhr.toLocal(),
      PrayerName.asr: pt.asr.toLocal(),
      PrayerName.maghrib: pt.maghrib.toLocal(),
      PrayerName.isha: pt.isha.toLocal(),
    });
  }

  /// Next fard prayer from [now], looking into tomorrow after Isha.
  (PrayerName, DateTime) next(DateTime now) {
    final today = forDate(now);
    final p = today.nextAfter(now);
    if (p != null) return (p, today[p]);
    final tomorrow = forDate(now.add(const Duration(days: 1)));
    return (PrayerName.fajr, tomorrow[PrayerName.fajr]);
  }
}
