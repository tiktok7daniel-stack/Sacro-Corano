import 'package:flutter_test/flutter_test.dart';
import 'package:mishkah/core/utils/arabic.dart';
import 'package:mishkah/domain/mp3quran.dart';
import 'package:mishkah/domain/ramadan.dart';
import 'package:mishkah/domain/recitation.dart';
import 'package:mishkah/domain/settings.dart';
import 'package:mishkah/domain/smart_reminders.dart';

import '../helpers.dart';

void main() {
  mp3quranTests();
  group('Recitation matching', () {
    final fatiha2 = expectedWords(testQuran().text(1, 2)); // الحمد لله رب العالمين

    test('splits Uthmani text into words with loose keys', () {
      expect(fatiha2.length, 4);
      expect(fatiha2.first.key, normalizeArabic(fatiha2.first.display));
    });

    test('a perfect recitation marks every word correct', () {
      final r = compareRecitation(fatiha2, 'الحمد لله رب العالمين', finished: true);
      expect(r.perfect, isTrue);
      expect(r.accuracy, 1);
    });

    test('spelling variants from the recogniser still match', () {
      final words = expectedWords(testQuran().text(1, 3)); // الرحمن الرحيم
      final r = compareRecitation(words, 'الرحمان الرحيم', finished: true);
      expect(r.perfect, isTrue);
    });

    test('a skipped word is missing, a swapped word is wrong', () {
      final skipped = compareRecitation(fatiha2, 'الحمد لله العالمين', finished: true);
      expect(skipped.states, [WordState.correct, WordState.correct, WordState.missing, WordState.correct]);
      final swapped = compareRecitation(fatiha2, 'الحمد لله كتاب العالمين', finished: true);
      expect(swapped.states[2], WordState.wrong);
      expect(swapped.correct, 3);
    });

    test('while listening, words not yet reached stay pending', () {
      final r = compareRecitation(fatiha2, 'الحمد لله', finished: false);
      expect(r.states, [WordState.correct, WordState.correct, WordState.pending, WordState.pending]);
      final done = compareRecitation(fatiha2, 'الحمد لله', finished: true);
      expect(done.missing, 2);
    });

    test('silence is pending until finished, then missing', () {
      expect(compareRecitation(fatiha2, '').pending, 4);
      expect(compareRecitation(fatiha2, '', finished: true).missing, 4);
    });

    test('a different verse scores low', () {
      final r = compareRecitation(fatiha2, 'قل هو الله احد', finished: true);
      expect(r.accuracy, lessThan(0.5));
    });
  });

  group('Ramadan', () {
    test('detects Ramadan days and counts down to the next one', () {
      final inRamadan = ramadanDay(DateTime(2026, 3, 1));
      expect(inRamadan, isNotNull);
      expect(inRamadan!.day, inInclusiveRange(1, 30));
      expect(ramadanDay(DateTime(2026, 6, 1)), isNull);
      expect(daysUntilRamadan(DateTime(2026, 3, 1)), 0);
      final n = daysUntilRamadan(DateTime(2026, 6, 1));
      expect(n, inInclusiveRange(200, 300));
      expect(ramadanDay(DateTime(2026, 6, 1).add(Duration(days: n))), isNotNull);
    });

    test('one juz a day in a 30-day month, two on the last day of a 29-day one', () {
      expect(juzForRamadanDay(1), (from: 1, to: 1));
      expect(juzForRamadanDay(30), (from: 30, to: 30));
      expect(juzForRamadanDay(29, length: 29), (from: 29, to: 30));
      expect(juzForRamadanDay(1, length: 29), (from: 1, to: 1));
      // Every juz is covered exactly once in either month length.
      for (final len in [29, 30]) {
        final seen = <int>[];
        for (var d = 1; d <= len; d++) {
          final r = juzForRamadanDay(d, length: len);
          for (var j = r.from; j <= r.to; j++) {
            seen.add(j);
          }
        }
        expect(seen, List.generate(30, (i) => i + 1), reason: 'length $len');
      }
    });

    test('missed days feed the qada count', () {
      var l = const FastingLedger();
      l = l.mark(1447, 1, 'f').mark(1447, 2, 'm').mark(1447, 3, 'm');
      expect(l.fasted(1447), 1);
      expect(l.missed(1447), 2);
      expect(l.qadaRemaining, 2);
      l = l.copyWith(qadaOwedExtra: 3, qadaDone: 4);
      expect(l.qadaOwed, 5);
      expect(l.qadaRemaining, 1);
      l = l.mark(1447, 2, null);
      expect(l.qadaOwed, 4);
      final round = FastingLedger.fromJson(l.toJson());
      expect(round.days, l.days);
      expect(round.qadaDone, 4);
    });
  });

  group('Smart reminders', () {
    // 2026-06-01 is a Monday.
    final now = DateTime(2026, 6, 1, 6);

    test('Friday Kahf reminders are scheduled at 8am on Fridays only', () {
      final plan = planReminders(const ReminderPrefs(kahf: true), now);
      expect(plan, isNotEmpty);
      for (final r in plan) {
        expect(r.kind, ReminderKind.kahf);
        expect(r.at.weekday, DateTime.friday);
        expect(r.at.hour, kahfHour);
      }
      expect(plan.length, 2); // two Fridays in 14 days
    });

    test('Monday/Thursday fasts are announced the evening before', () {
      final plan = planReminders(const ReminderPrefs(fastMonThu: true), now, days: 7);
      expect(plan.every((r) => r.kind == ReminderKind.fastMonThu && r.at.hour == fastEveHour), isTrue);
      // The eve of Monday is Sunday, the eve of Thursday is Wednesday.
      expect(plan.map((r) => r.at.weekday), containsAll([DateTime.sunday, DateTime.wednesday]));
      expect(plan.map((r) => r.weekday).toSet(), {DateTime.monday, DateTime.thursday});
    });

    test('nothing is scheduled when everything is off, and past times are dropped', () {
      expect(planReminders(const ReminderPrefs(), now), isEmpty);
      final late = DateTime(2026, 6, 1, 23);
      final plan = planReminders(const ReminderPrefs(salawat: true, salawatHour: 17), late, days: 2);
      expect(plan.length, 1); // today's 17:00 has passed
      expect(plan.single.at, DateTime(2026, 6, 2, 17));
    });

    test('voluntary fasts are never suggested during Ramadan', () {
      // 2026-03-02 is a Monday inside Ramadan 1447.
      expect(fastingFor(DateTime(2026, 3, 2)), isNull);
      final plan = planReminders(const ReminderPrefs(fastMonThu: true, fastWhite: true), DateTime(2026, 2, 25), days: 10);
      for (final r in plan) {
        expect(ramadanDay(DateTime(r.at.year, r.at.month, r.at.day).add(const Duration(days: 1))), isNull);
      }
    });

    test('white days are found from the Hijri date', () {
      final found = <DateTime>[];
      for (var i = 0; i < 40; i++) {
        final d = DateTime(2026, 6, 1).add(Duration(days: i));
        final f = fastingFor(d);
        if (f != null && f.white) found.add(d);
      }
      expect(found.length, inInclusiveRange(3, 6));
    });

    test('new settings round-trip through JSON', () {
      const s = AppSettings(kahfReminder: true, fastWhiteReminder: true, salawatHour: 9, suhoorLeadMinutes: 60, ramadanReminders: false);
      final back = AppSettings.fromJson(s.toJson());
      expect(back.kahfReminder, isTrue);
      expect(back.fastWhiteReminder, isTrue);
      expect(back.fastMonThuReminder, isFalse);
      expect(back.salawatHour, 9);
      expect(back.suhoorLeadMinutes, 60);
      expect(back.ramadanReminders, isFalse);
      expect(AppSettings.fromJson({}).ramadanReminders, isTrue);
    });
  });
}

void mp3quranTests() {
  group('MP3Quran library', () {
    test('parses reciters, sets and surah lists and drops broken records', () {
      final list = parseFullReciters([
        {
          'id': 1,
          'name': 'عبد الباسط عبد الصمد',
          'moshaf': [
            {'id': 10, 'name': 'حفص - مرتل', 'server': 'https://server7.mp3quran.net/basit', 'surah_list': '1,2,114,115,x'},
            {'id': 11, 'name': 'http only', 'server': 'http://insecure.example/a/', 'surah_list': '1'},
            {'id': 12, 'name': 'empty', 'server': 'https://s.example/b/', 'surah_list': ''},
          ],
        },
        {'id': 2, 'name': '', 'moshaf': []},
        'not a map',
      ]);
      expect(list.length, 1);
      final m = list.single.moshafs.single;
      expect(m.surahs, {1, 2, 114});
      expect(m.url(1).toString(), 'https://server7.mp3quran.net/basit/001.mp3');
      expect(m.url(114).toString(), 'https://server7.mp3quran.net/basit/114.mp3');
      expect(m.has(3), isFalse);
    });
  });
}
