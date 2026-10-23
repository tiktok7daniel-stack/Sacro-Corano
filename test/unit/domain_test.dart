import 'package:flutter_test/flutter_test.dart';
import 'package:mishkah/domain/achievements.dart';
import 'package:mishkah/domain/khatma.dart';
import 'package:mishkah/domain/prayer_times.dart';
import 'package:mishkah/domain/qibla.dart';
import 'package:mishkah/domain/quran_models.dart';
import 'package:mishkah/domain/reciters.dart';
import 'package:mishkah/domain/settings.dart';
import 'package:mishkah/domain/srs.dart';
import 'package:mishkah/domain/translation_helpers.dart';
import 'package:mishkah/domain/user_models.dart';

void main() {
  group('Qibla', () {
    test('bearings from known cities', () {
      expect(qiblaBearing(51.5072, -0.1276), closeTo(118.99, 0.1)); // London
      expect(qiblaBearing(40.7128, -74.0060), closeTo(58.48, 0.1)); // New York
      expect(qiblaBearing(-6.2088, 106.8456), closeTo(295.15, 0.1)); // Jakarta
    });

    test('distance to the Kaaba', () {
      expect(distanceToKaabaKm(51.5072, -0.1276), closeTo(4794, 5));
      expect(distanceToKaabaKm(kaabaLat, kaabaLng), closeTo(0, 0.001));
    });

    test('angleDelta and smoothing wrap around north', () {
      expect(angleDelta(350, 10), 20);
      expect(angleDelta(10, 350), -20);
      expect(smoothHeading(359, 1, factor: 0.5), closeTo(0, 1e-9));
    });
  });

  group('Prayer times', () {
    const makkah = AppSettings(lat: 21.4225, lng: 39.8262, calcMethod: 'umm_al_qura');

    test('are ordered through the day', () {
      final day = const PrayerCalculator(makkah).forDate(DateTime(2026, 3, 1));
      final order = PrayerName.values.map((p) => day[p]).toList();
      for (var i = 1; i < order.length; i++) {
        expect(order[i].isAfter(order[i - 1]), isTrue, reason: '${PrayerName.values[i]}');
      }
    });

    test('Umm al-Qura isha is 90 minutes after maghrib', () {
      final day = const PrayerCalculator(makkah).forDate(DateTime(2026, 3, 1));
      expect(day[PrayerName.isha].difference(day[PrayerName.maghrib]).inMinutes, 90);
    });

    test('manual offsets are applied', () {
      final base = const PrayerCalculator(makkah).forDate(DateTime(2026, 3, 1));
      final shifted = PrayerCalculator(makkah.copyWith(prayerOffsets: {'fajr': 5})).forDate(DateTime(2026, 3, 1));
      expect(shifted[PrayerName.fajr].difference(base[PrayerName.fajr]).inMinutes, 5);
    });

    test('hanafi asr is later than standard', () {
      final std = const PrayerCalculator(makkah).forDate(DateTime(2026, 3, 1));
      final han = PrayerCalculator(makkah.copyWith(madhab: 'hanafi')).forDate(DateTime(2026, 3, 1));
      expect(han[PrayerName.asr].isAfter(std[PrayerName.asr]), isTrue);
    });

    test('next() rolls over to tomorrow after isha', () {
      const calc = PrayerCalculator(makkah);
      final day = calc.forDate(DateTime(2026, 3, 1));
      final (p, at) = calc.next(day[PrayerName.isha].add(const Duration(minutes: 1)));
      expect(p, PrayerName.fajr);
      expect(at.isAfter(day[PrayerName.isha]), isTrue);
      final (p2, _) = calc.next(day[PrayerName.fajr].add(const Duration(minutes: 1)));
      expect(p2, PrayerName.dhuhr, reason: 'sunrise is not a prayer');
    });

    test('currentAt / nextAfter', () {
      final day = const PrayerCalculator(makkah).forDate(DateTime(2026, 3, 1));
      final t = day[PrayerName.asr].add(const Duration(minutes: 3));
      expect(day.currentAt(t), PrayerName.asr);
      expect(day.nextAfter(t), PrayerName.maghrib);
    });

    test('every listed method resolves', () {
      for (final m in prayerMethods) {
        final d = PrayerCalculator(makkah.copyWith(calcMethod: m.id)).forDate(DateTime(2026, 6, 1));
        expect(d[PrayerName.dhuhr].isAfter(d[PrayerName.fajr]), isTrue, reason: m.id);
      }
    });
  });

  group('SM-2', () {
    HifzCard card() => HifzCard(id: '1:1-5', surah: 1, from: 1, to: 5, due: DateTime(2026, 1, 1));
    final now = DateTime(2026, 1, 1, 10);

    test('intervals grow 1 → 6 → ~15 on good recall', () {
      var c = reviewCard(card(), 4, now: now);
      expect(c.interval, 1);
      c = reviewCard(c, 4, now: now);
      expect(c.interval, 6);
      c = reviewCard(c, 4, now: now);
      expect(c.interval, 15);
      expect(c.due, DateTime(2026, 1, 16));
      expect(c.reviews, 3);
    });

    test('forgetting resets repetitions and lowers easiness', () {
      var c = reviewCard(card(), 5, now: now);
      c = reviewCard(c, 5, now: now);
      final ef = c.easiness;
      c = reviewCard(c, 1, now: now, mistakes: 3);
      expect(c.repetitions, 0);
      expect(c.interval, 1);
      expect(c.easiness, lessThan(ef));
      expect(c.mistakes, 3);
    });

    test('easiness never drops below 1.3', () {
      var c = card();
      for (var i = 0; i < 20; i++) {
        c = reviewCard(c, 0, now: now);
      }
      expect(c.easiness, 1.3);
    });

    test('stages and due', () {
      expect(card().stage, 0);
      expect(card().isDue(DateTime(2026, 1, 1)), isTrue);
      final c = card().copyWith(interval: 30, reviews: 5, due: DateTime(2026, 2, 1));
      expect(c.stage, 3);
      expect(c.isDue(DateTime(2026, 1, 15)), isFalse);
    });

    test('json round trip', () {
      final c = reviewCard(card(), 4, now: now, mistakes: 2);
      final back = HifzCard.fromJson(c.toJson());
      expect(back.toJson(), c.toJson());
    });

    test('chunkSurah merges a short tail', () {
      expect(chunkSurah(7), [(1, 7)]);
      expect(chunkSurah(12), [(1, 5), (6, 12)]);
      expect(chunkSurah(15), [(1, 5), (6, 10), (11, 15)]);
      expect(chunkSurah(3, size: 5), [(1, 3)]);
    });
  });

  group('Khatma', () {
    final start = DateTime(2026, 1, 1);

    test('even plan targets ~20 pages over 30 days', () {
      final p = KhatmaPlan(start: start, targetDays: 30);
      expect(p.todayTarget(start), 21);
      expect(p.end, DateTime(2026, 1, 30));
    });

    test('missed days are absorbed by the remaining days', () {
      final p = KhatmaPlan(start: start, targetDays: 30);
      final later = DateTime(2026, 1, 11); // 10 days in, nothing read
      expect(p.daysLeft(later), 20);
      expect(p.todayTarget(later), 31);
      expect(p.scheduleDelta(later), lessThan(0));
    });

    test('busy weekdays carry half the load', () {
      // 2026-01-02 is a Friday (weekday 5).
      final p = KhatmaPlan(start: start, targetDays: 7, busyWeekdays: {5});
      final friday = DateTime(2026, 1, 2);
      final saturday = DateTime(2026, 1, 3);
      expect(p.todayTarget(friday), lessThan(p.todayTarget(saturday)));
    });

    test('markRead logs pages for the day and never goes back', () {
      var p = KhatmaPlan(start: start, targetDays: 30);
      p = p.markRead(10, start);
      p = p.markRead(5, start);
      expect(p.pagesRead, 10);
      expect(p.readOn(start), 10);
      p = p.markRead(700, start);
      expect(p.done, isTrue);
      expect(p.todayTarget(start), 0);
      final r = p.restart(DateTime(2026, 2, 1));
      expect(r.completedCount, 1);
      expect(r.pagesRead, 0);
    });

    test('json round trip', () {
      final p = KhatmaPlan(start: start, targetDays: 20, busyWeekdays: {5, 6}).markRead(42, start);
      final back = KhatmaPlan.fromJson(p.toJson());
      expect(back.toJson(), p.toJson());
    });

    test('streaks', () {
      final days = {'2026-01-01', '2026-01-02', '2026-01-03', '2026-01-05'};
      expect(currentStreak(days, DateTime(2026, 1, 5)), 1);
      expect(currentStreak(days, DateTime(2026, 1, 4)), 3, reason: 'yesterday still counts');
      expect(currentStreak(days, DateTime(2026, 1, 7)), 0);
      expect(longestStreak(days), 3);
      expect(longestStreak({}), 0);
      expect(dayKey(DateTime(2026, 3, 9)), '2026-03-09');
    });
  });

  group('Models', () {
    test('AyahRef / AyahRange parsing and ordering', () {
      expect(AyahRef.parse('2:255'), const AyahRef(2, 255));
      expect(const AyahRef(2, 255).compareTo(const AyahRef(3, 1)), lessThan(0));
      expect(AyahRange.parse('12:4-101').length, 98);
      expect(AyahRange.parse('2:255').to, 255);
      expect(AyahRange.parse('71').to, -1);
      expect(AyahRange.parse('12:4-101').toString(), '12:4-101');
    });

    test('settings json round trip keeps every field', () {
      const s = AppSettings(
        lang: 'en',
        lat: 45.5,
        lng: 9.2,
        placeName: 'Milano',
        prayerOffsets: {'isha': 3},
        kidsPin: '1234',
        quranFontSize: 34,
        onboarded: true,
      );
      final back = AppSettings.fromJson(s.toJson());
      expect(back.toJson(), s.toJson());
      expect(back.copyWith(clearKidsPin: true).kidsPin, isNull);
    });

    test('settings tolerate garbage', () {
      final s = AppSettings.fromJson({'lang': 3, 'theme': 'nope', 'quranFontSize': '30'});
      expect(s.lang, 'ar');
      expect(s.hasLocation, isFalse);
    });

    test('user models round trip', () {
      final b = Bookmark(ref: const AyahRef(1, 1), collection: 'x', created: DateTime(2026));
      expect(Bookmark.fromJson(b.toJson()).ref, b.ref);
      final r = Reflection(id: 'a', ref: const AyahRef(2, 3), text: 't', tags: const ['sabr'], created: DateTime(2026));
      expect(Reflection.fromJson(r.toJson()).tags, ['sabr']);
      const d = DayActivity(ayahsRead: 3, prayers: {'fajr'});
      expect(DayActivity.fromJson(d.toJson()).prayers, {'fajr'});
      expect(const DayActivity().active, isFalse);
      expect(Dhikr.fromJson(defaultDhikr.first.toJson()).target, 33);
    });

    test('reciter urls', () {
      final r = reciterById('alafasy');
      expect(r.url(2, 255).toString(), 'https://everyayah.com/data/Alafasy_128kbps/002255.mp3');
      expect(reciterById('unknown').id, reciters.first.id);
      expect(reciters.length, greaterThanOrEqualTo(10));
      expect(reciters.map((r) => r.id).toSet().length, reciters.length);
    });

    test('cleanTranslation strips tags', () {
      expect(cleanTranslation(' In the <sup>1</sup> name  '), 'In the 1 name');
    });
  });

  group('Achievements', () {
    test('computed from activity', () {
      final input = AchievementInput(
        days: {
          for (var i = 1; i <= 7; i++)
            '2026-01-0$i': const DayActivity(ayahsRead: 20, tasbih: 200, prayers: {'fajr', 'dhuhr', 'asr', 'maghrib', 'isha'}),
        },
        khatmasCompleted: 0,
        hifzCards: 1,
        matureCards: 0,
        reflections: 0,
        kidsStars: 0,
      );
      final got = achievements.where((a) => a.test(input)).map((a) => a.id).toSet();
      expect(got, containsAll(['first_step', 'reader_100', 'streak_7', 'tasbih_1000', 'prayers_7', 'hifz_start']));
      expect(got, isNot(contains('khatma_1')));
      expect(achievements.map((a) => a.id).toSet().length, achievements.length);
    });
  });
}
