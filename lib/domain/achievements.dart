import 'khatma.dart';
import 'user_models.dart';

/// Badges earned from the user's own activity (computed, never uploaded).
class Achievement {
  const Achievement(this.id, this.titleAr, this.titleEn, this.descAr, this.descEn, this.test);
  final String id;
  final String titleAr;
  final String titleEn;
  final String descAr;
  final String descEn;
  final bool Function(AchievementInput) test;

  String title(String lang) => lang == 'ar' ? titleAr : titleEn;
  String desc(String lang) => lang == 'ar' ? descAr : descEn;
}

class AchievementInput {
  const AchievementInput({
    required this.days,
    required this.khatmasCompleted,
    required this.hifzCards,
    required this.matureCards,
    required this.reflections,
    required this.kidsStars,
  });

  final Map<String, DayActivity> days;
  final int khatmasCompleted;
  final int hifzCards;
  final int matureCards;
  final int reflections;
  final int kidsStars;

  int get totalAyahs => days.values.fold(0, (s, d) => s + d.ayahsRead);
  int get totalTasbih => days.values.fold(0, (s, d) => s + d.tasbih);
  Set<String> get activeDays => {for (final e in days.entries) if (e.value.active) e.key};
  int get fullPrayerDays => days.values.where((d) => d.prayers.length >= 5).length;
  int get longest => longestStreak(activeDays);
}

final achievements = <Achievement>[
  Achievement('first_step', 'الخطوة الأولى', 'First step', 'قرأت أول آية في مشكاة', 'Read your first verse', (i) => i.totalAyahs >= 1),
  Achievement('reader_100', 'قارئ', 'Reader', 'قرأت ١٠٠ آية', 'Read 100 verses', (i) => i.totalAyahs >= 100),
  Achievement('reader_1000', 'صاحب ورد', 'Devoted reader', 'قرأت ١٠٠٠ آية', 'Read 1,000 verses', (i) => i.totalAyahs >= 1000),
  Achievement('khatma_1', 'الختمة الأولى', 'First khatma', 'أتممت ختمة كاملة', 'Completed a full khatma', (i) => i.khatmasCompleted >= 1),
  Achievement('streak_7', 'أسبوع مواظبة', 'Week streak', '٧ أيام متتالية', '7 days in a row', (i) => i.longest >= 7),
  Achievement('streak_30', 'شهر مواظبة', 'Month streak', '٣٠ يومًا متتاليًا', '30 days in a row', (i) => i.longest >= 30),
  Achievement('tasbih_1000', 'ذاكر', 'Rememberer', '١٠٠٠ تسبيحة', '1,000 tasbih', (i) => i.totalTasbih >= 1000),
  Achievement('tasbih_10000', 'كثير الذكر', 'Abundant dhikr', '١٠٠٠٠ تسبيحة', '10,000 tasbih', (i) => i.totalTasbih >= 10000),
  Achievement('prayers_7', 'محافظ', 'Steadfast', 'سجّلت الصلوات الخمس ٧ أيام', 'Logged all five prayers for 7 days', (i) => i.fullPrayerDays >= 7),
  Achievement('hifz_start', 'بداية الحفظ', 'Hifz begun', 'أضفت أول مقطع للحفظ', 'Added your first memorisation unit', (i) => i.hifzCards >= 1),
  Achievement('hifz_mature', 'حفظ متين', 'Solid hifz', '١٠ مقاطع راسخة', '10 mature memorisation units', (i) => i.matureCards >= 10),
  Achievement('reflect_10', 'متدبّر', 'Reflective', 'كتبت ١٠ تدبّرات', 'Wrote 10 reflections', (i) => i.reflections >= 10),
  Achievement('kids_stars', 'نجم صغير', 'Little star', 'جمعت ٢٠ نجمة في وضع الأطفال', 'Collected 20 stars in kids mode', (i) => i.kidsStars >= 20),
];
