import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:mishkah/app/providers.dart';
import 'package:mishkah/core/utils/hijri.dart';
import 'package:mishkah/data/local/storage.dart';
import 'package:mishkah/data/quran/word_data.dart';
import 'package:mishkah/domain/prayer_times.dart';
import 'package:mishkah/domain/recitation_match.dart';
import 'package:mishkah/domain/settings.dart';
import 'package:mishkah/domain/user_models.dart';
import 'package:mishkah/features/quran/widgets/tajweed_text.dart';
import 'package:mishkah/features/ramadan/ramadan_screen.dart';
import 'package:mishkah/services/notifications.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../fakes.dart';
import '../helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('recitation matching', () {
    List<ExpectedWord> words(String text) => verseWords(text).map(ExpectedWord.new).toList();

    test('normalises Uthmani spelling and everyday spelling alike', () {
      expect(normalizeSpoken('ٱلرَّحۡمَٰنِ'), normalizeSpoken('الرحمن'));
      expect(normalizeSpoken('ٱلۡعَٰلَمِينَ', daggerAsAlef: true), normalizeSpoken('العالمين'));
      expect(normalizeSpoken('أَحَدٌ'), 'احد');
      expect(normalizeSpoken('ٱلصَّلَوٰةَ'), 'الصلوه');
      expect(wordsMatch('الصلاة', ExpectedWord('ٱلصَّلَوٰةَ')), isTrue);
      expect(wordsMatch('العالمين', ExpectedWord('ٱلۡعَٰلَمِينَ')), isTrue);
      expect(wordsMatch('قل', ExpectedWord('قُلۡ')), isTrue);
      expect(wordsMatch('هو', ExpectedWord('قُلۡ')), isFalse);
    });

    test('marks recited, skipped and pending words', () {
      final w = words('قُلۡ هُوَ ٱللَّهُ أَحَدٌ ٱللَّهُ ٱلصَّمَدُ');
      var a = alignRecitation(w, ['قل', 'هو', 'الله']);
      expect(a.states.take(3), everyElement(WordState.correct));
      expect(a.position, 3);
      expect(a.done, isFalse);
      a = alignRecitation(w, ['قل', 'هو', 'الله', 'الله', 'الصمد']);
      expect(a.states[3], WordState.missed, reason: 'أحد was skipped');
      expect(a.done, isTrue);
      expect(a.correct, 5);
      expect(a.missed, 1);
      // Extra words (a repeated word, a closing phrase) are ignored.
      a = alignRecitation(w, ['قل', 'قل', 'هو', 'صدق']);
      expect(a.position, 2);
    });

    test('handles glued and split words from the recogniser', () {
      final w = words('ذَٰلِكَ ٱلۡكِتَٰبُ لَا رَيۡبَۛ فِيهِۛ');
      expect(alignRecitation(w, ['ذلك', 'الكتاب', 'لاريب', 'فيه']).correct, 5);
      expect(alignRecitation(words('وَبِٱلۡأٓخِرَةِ'), ['وبال', 'اخره']).correct, 1);
    });
  });

  group('tajweed & word data', () {
    final tajweed = TajweedData.parse(File('assets/data/tajweed.json.gz').readAsBytesSync());
    final wbw = WordByWord.parse(File('assets/data/wbw_en.json.gz').readAsBytesSync());

    test('every verse has runs inside its text', () {
      final q = testQuran();
      expect(tajweed.classes, tajweedClassOrder);
      var withRuns = 0;
      for (final s in q.surahs) {
        for (var a = 1; a <= s.ayahCount; a++) {
          final r = tajweed.runs(s.number, a);
          final len = q.text(s.number, a).runes.length;
          for (var i = 0; i + 2 < r.length; i += 3) {
            expect(r[i] < r[i + 1] && r[i + 1] <= len && r[i + 2] < tajweed.classes.length, isTrue, reason: '${s.number}:$a');
          }
          if (r.isNotEmpty) withRuns++;
        }
      }
      expect(withRuns, greaterThan(5500));
      expect(tajweed.runs(0, 1), isEmpty);
      expect(tajweed.runs(1, 99), isEmpty);
    });

    test('word meanings line up with the words of the text', () {
      final q = testQuran();
      expect(wbw.words(1, 1).map((g) => g.meaning), contains('the Most Merciful'));
      var aligned = 0;
      for (final s in q.surahs) {
        for (var a = 1; a <= s.ayahCount; a++) {
          final g = wbw.words(s.number, a);
          if (g.isEmpty) continue;
          aligned++;
          expect(g.length, verseWords(q.text(s.number, a)).length, reason: '${s.number}:$a');
        }
      }
      expect(aligned, greaterThan(6200));
      expect(wbw.words(115, 1), isEmpty);
    });

    test('verse spans colour runs, drop ۞ and number the words', () {
      final text = testQuran().text(1, 1);
      final pressed = <int>[];
      final recs = <dynamic>[];
      final spans = verseSpans(
        '۞ $text',
        runs: [for (var i = 0; i + 2 < tajweed.runs(1, 1).length; i += 3) ...[tajweed.runs(1, 1)[i] + 2, tajweed.runs(1, 1)[i + 1] + 2, tajweed.runs(1, 1)[i + 2]]],
        classes: tajweed.classes,
        colors: tajweedColors(dark: true),
        onWordLongPress: pressed.add,
        recognizers: recs.cast(),
      );
      final plain = spans.map((s) => (s as TextSpan).text ?? '').join();
      expect(plain.contains('۞'), isFalse);
      expect(plain.trim(), text);
      expect(spans.whereType<TextSpan>().any((s) => s.style?.color != null), isTrue);
      expect(recs, hasLength(4));
      expect(tajweedColors(dark: false).keys, containsAll(tajweedClassOrder));
    });
  });

  group('settings and fasting', () {
    late Directory dir;
    late Storage storage;
    late ProviderContainer c;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('mishkah_v13');
      storage = await Storage.initForTest(dir.path);
      c = ProviderContainer(overrides: [storageProvider.overrideWithValue(storage)]);
    });
    tearDown(() async {
      c.dispose();
      await storage.settle();
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('new settings round-trip', () {
      const s = AppSettings(tajweed: false, adhanSound: 'short', iqamaAlert: true, iqamaMinutes: 20, monThuReminder: true, kahfReminder: false);
      final back = AppSettings.fromJson(s.toJson());
      expect(back.tajweed, isFalse);
      expect(back.adhanSound, 'short');
      expect(back.iqamaAlert, isTrue);
      expect(back.iqamaMinutes, 20);
      expect(back.monThuReminder, isTrue);
      expect(back.kahfReminder, isFalse);
      expect(const AppSettings().copyWith(salawatReminder: false, ramadanReminders: false, whiteDaysReminder: false, occasionFastReminder: false).salawatReminder, isFalse);
      expect(AppSettings.fromJson({'adhanSound': 3}).adhanSound, 'full');
    });

    test('fasting log cycles days and counts make-up fasts', () {
      final f = c.read(fastingProvider.notifier);
      final d = DateTime(2027, 2, 10);
      f.cycle(d);
      expect(c.read(fastingProvider).days.values.single, 'fasted');
      f.cycle(d);
      f.cycle(DateTime(2027, 2, 11));
      f.set(DateTime(2027, 2, 12), 'excused');
      final log = c.read(fastingProvider);
      expect(log.missedCount, 2);
      expect(log.fastedCount, 1);
      f.addOwed(3);
      f.addQadaDone(1);
      expect(c.read(fastingProvider).qadaRemaining, 4);
      f.cycle(d);
      f.cycle(d);
      expect(c.read(fastingProvider).days.containsKey('2027-02-10'), isFalse, reason: 'four taps return to none');
      final c2 = ProviderContainer(overrides: [storageProvider.overrideWithValue(storage)]);
      expect(c2.read(fastingProvider).extraOwed, 3);
      c2.dispose();
      expect(FastingLog.fromJson(const {}).qadaRemaining, 0);
    });
  });

  group('ramadan helpers', () {
    DateTime firstRamadanDay() {
      var d = DateTime(2027, 1, 1);
      while (HijriDate.fromGregorian(d).month != 9) {
        d = d.add(const Duration(days: 1));
      }
      return d;
    }

    test('days of the current or next Ramadan', () {
      final start = firstRamadanDay();
      final before = ramadanDays(start.subtract(const Duration(days: 10)));
      expect(before.first, start);
      expect(before.length, inInclusiveRange(29, 30));
      final during = ramadanDays(start.add(const Duration(days: 5, hours: 13)));
      expect(during.first, start);
    });

    test('next fasting moment switches between suhoor and iftar', () {
      final calc = PrayerCalculator(const AppSettings(lat: 21.42, lng: 39.82, calcMethod: 'umm_al_qura'));
      final day = DateTime(2027, 2, 15);
      final t = calc.forDate(day);
      expect(nextFastingMoment(calc, t[PrayerName.fajr].subtract(const Duration(hours: 1)))!.$1, 'suhoor_ends');
      expect(nextFastingMoment(calc, t[PrayerName.dhuhr])!.$1, 'iftar_in');
      final night = nextFastingMoment(calc, t[PrayerName.isha])!;
      expect(night.$1, 'suhoor_ends');
      expect(night.$2.day, 16);
    });
  });

  group('adhan and smart reminders', () {
    late ChannelRecorder rec;
    late Directory tmp;
    setUp(() async {
      tmp = Directory.systemTemp.createTempSync('mishkah_v13n');
      PathProviderPlatform.instance = FakePathProvider(tmp);
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      rec = ChannelRecorder('dexterous.com/flutter/local_notifications', reply: (c) => c.method == 'initialize' ? true : null);
      await Notifications.instance.initTimezones();
    });
    tearDown(() {
      rec.dispose();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    Map<dynamic, dynamic> details(MethodCall c) => ((c.arguments as Map)['platformSpecifics'] as Map?) ?? const {};

    test('adhan channels carry the bundled sounds', () {
      expect(Notifications.adhanChannel('full').channelId, 'adhan_full');
      expect((Notifications.adhanChannel('short').sound as RawResourceAndroidNotificationSound).sound, 'mishkah_adhan_short');
      expect(Notifications.adhanChannel('silent').playSound, isFalse);
      expect(Notifications.adhanChannel('system').channelId, 'prayer_times');
    });

    test('prayers use the adhan channel and add iqama alerts', () async {
      const s = AppSettings(lat: 21.42, lng: 39.82, adhanSound: 'full', iqamaAlert: true, iqamaMinutes: 10);
      await Notifications.instance.schedulePrayers(s, titles: {for (final p in PrayerName.values) p: p.name}, body: 'b', iqama: 'iqama', days: 2);
      final calls = rec.named('zonedSchedule').toList();
      expect(calls.where((c) => details(c)['channelId'] == 'adhan_full'), isNotEmpty);
      expect(calls.where((c) => (c.arguments as Map)['title'] == 'iqama'), isNotEmpty);
      await Notifications.instance.testAdhan('short', 't', 'b');
      expect(rec.named('show').any((c) => details(c)['channelId'] == 'adhan_short'), isTrue);
    });

    test('Friday, fasting-eve and Ramadan reminders', () async {
      const t = SmartTexts(kahf: 'kahf', salawat: 'salawat', whiteDays: 'white', monThu: 'monthu', arafah: 'arafah', ashura: 'ashura', suhoor: 'suhoor', iftar: 'iftar');
      // A Thursday morning: Friday's reminders and Sunday's Mon/Thu eve fall in the window.
      var from = DateTime.now().add(const Duration(days: 1));
      while (from.weekday != DateTime.thursday) {
        from = from.add(const Duration(days: 1));
      }
      from = DateTime(from.year, from.month, from.day, 6);
      await Notifications.instance.scheduleSmart(const AppSettings(lat: 21.42, lng: 39.82, monThuReminder: true), t, from: from);
      var titles = rec.named('zonedSchedule').map((c) => (c.arguments as Map)['title']).toList();
      expect(titles, containsAll(['kahf', 'salawat']));
      expect(titles.contains('monthu') || titles.contains('white'), isTrue);

      // Ramadan: suhoor and iftar every day.
      from = DateTime(2027, 1, 1);
      while (HijriDate.fromGregorian(from).month != 9) {
        from = from.add(const Duration(days: 1));
      }
      rec.calls.clear();
      await Notifications.instance.scheduleSmart(const AppSettings(lat: 21.42, lng: 39.82), t, from: from.add(const Duration(days: 3)), days: 3);
      titles = rec.named('zonedSchedule').map((c) => (c.arguments as Map)['title']).toList();
      expect(titles.where((x) => x == 'iftar').length, greaterThanOrEqualTo(2));
      expect(titles, contains('suhoor'));
      expect(titles, isNot(contains('white')), reason: 'no fasting reminders in Ramadan');

      // Everything off: nothing scheduled.
      rec.calls.clear();
      await Notifications.instance.scheduleSmart(
        const AppSettings(kahfReminder: false, salawatReminder: false, whiteDaysReminder: false, monThuReminder: false, occasionFastReminder: false, ramadanReminders: false),
        t,
        from: DateTime(2026, 10, 22),
      );
      expect(rec.named('zonedSchedule'), isEmpty);
    });
  });
}
