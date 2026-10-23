import 'package:flutter_test/flutter_test.dart';
import 'package:mishkah/core/utils/arabic.dart';
import 'package:mishkah/core/utils/hijri.dart';

void main() {
  group('Arabic digits', () {
    test('converts western digits only', () {
      expect(toArabicDigits('12:05 pm'), '١٢:٠٥ pm');
      expect(localNum(604, 'ar'), '٦٠٤');
      expect(localNum(604, 'en'), '604');
    });
  });

  group('normalizeArabic', () {
    test('removes harakat and Quranic marks', () {
      expect(normalizeArabic('بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ'), 'بسم الله الرحمن الرحيم');
    });

    test('dagger alef variant matches everyday spelling', () {
      expect(normalizeArabic('ٱلصِّرَٰطَ', daggerAsAlef: true), 'الصراط');
      expect(normalizeArabic('ٱلصِّرَٰطَ'), 'الصرط');
    });

    test('unifies alef, yaa and taa marbuta forms', () {
      expect(normalizeArabic('إِنَّ أَكْرَمَكُمْ'), 'ان اكرمكم');
      expect(normalizeArabic('هُدًى'), 'هدي');
      expect(normalizeArabic('رَحْمَة'), 'رحمه');
    });

    test('isArabic', () {
      expect(isArabic('mercy'), isFalse);
      expect(isArabic('رحمة'), isTrue);
    });
  });

  group('HijriDate', () {
    test('Umm al-Qura known dates', () {
      expect(HijriDate.fromGregorian(DateTime(2024, 3, 11)), const HijriDate(1445, 9, 1));
      expect(HijriDate.fromGregorian(DateTime(2026, 2, 18)), const HijriDate(1447, 9, 1));
      expect(HijriDate.fromGregorian(DateTime(2023, 7, 19)), const HijriDate(1445, 1, 1));
      expect(HijriDate.fromGregorian(DateTime(2026, 10, 23)), const HijriDate(1448, 5, 12));
    });

    test('offset shifts the day', () {
      expect(HijriDate.fromGregorian(DateTime(2026, 10, 23), offsetDays: 1).day, 13);
      expect(HijriDate.fromGregorian(DateTime(2026, 10, 23), offsetDays: -1).day, 11);
    });

    test('tabular fallback is within a day of Umm al-Qura', () {
      for (final d in [DateTime(2010, 5, 5), DateTime(2020, 1, 1), DateTime(2030, 7, 7)]) {
        final a = HijriDate.fromGregorian(d);
        final b = HijriDate.tabular(d);
        expect(a.year, b.year);
        expect(a.month, b.month);
        expect((a.day - b.day).abs() <= 1, isTrue, reason: '$d: $a vs $b');
      }
    });

    test('month names and daysUntil', () {
      expect(const HijriDate(1447, 9, 1).monthName('ar'), 'رمضان');
      expect(const HijriDate(1447, 9, 1).monthName('en'), 'Ramadan');
      expect(HijriDate.daysUntil(9, 1, from: DateTime(2026, 2, 18)), 0);
      expect(HijriDate.daysUntil(9, 1, from: DateTime(2026, 2, 8)), 10);
    });
  });
}
