import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mishkah/app/bootstrap.dart';
import 'package:mishkah/data/local/storage.dart';
import 'package:mishkah/domain/prayer_times.dart';
import 'package:mishkah/domain/reciters.dart';
import 'package:mishkah/domain/settings.dart';
import 'package:mishkah/services/audio.dart';
import 'package:mishkah/services/backup.dart';
import 'package:mishkah/services/location.dart';
import 'package:mishkah/services/notifications.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('mishkah_services');
    PathProviderPlatform.instance = FakePathProvider(tmp);
  });
  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('Notifications', () {
    late ChannelRecorder rec;
    const titles = {
      PrayerName.fajr: 'fajr',
      PrayerName.sunrise: 'sunrise',
      PrayerName.dhuhr: 'dhuhr',
      PrayerName.asr: 'asr',
      PrayerName.maghrib: 'maghrib',
      PrayerName.isha: 'isha',
    };

    setUp(() async {
      AndroidFlutterLocalNotificationsPlugin.registerWith();
      rec = ChannelRecorder('dexterous.com/flutter/local_notifications', reply: (c) => switch (c.method) {
            'initialize' => true,
            'pendingNotificationRequests' => [
                {'id': 1000, 'title': 'old', 'body': '', 'payload': null},
                {'id': 42, 'title': 'other', 'body': '', 'payload': null},
              ],
            _ => null,
          });
      await Notifications.instance.initTimezones();
    });
    tearDown(() => rec.dispose());

    test('schedules five adhans a day for a week, skipping disabled prayers', () async {
      const s = AppSettings(lat: 45.46, lng: 9.19, adhanEnabled: {'fajr': true, 'dhuhr': true, 'asr': false, 'maghrib': true, 'isha': true});
      await Notifications.instance.schedulePrayers(s, titles: titles, body: 'b', days: 7);
      final scheduled = rec.named('zonedSchedule').toList();
      // 4 prayers × 7 days, minus those already past today.
      expect(scheduled.length, inInclusiveRange(4 * 6, 4 * 7));
      expect(scheduled.any((c) => (c.arguments as Map)['title'] == 'asr'), isFalse);
      final cancelled = rec.named('cancel').map((c) => (c.arguments as Map)['id']).toList();
      expect(cancelled, [1000], reason: 'only pending alerts in the prayer range are cleared');
    });

    test('pre-adhan reminders double the alerts', () async {
      const s = AppSettings(lat: 45.46, lng: 9.19, preAdhanMinutes: 10);
      await Notifications.instance.schedulePrayers(s, titles: titles, body: 'b', days: 2);
      final n = rec.named('zonedSchedule').length;
      expect(n, greaterThanOrEqualTo(10));
    });

    test('no location → nothing scheduled', () async {
      await Notifications.instance.schedulePrayers(const AppSettings(), titles: titles, body: 'b');
      expect(rec.named('zonedSchedule'), isEmpty);
    });

    test('azkar and wird reminders', () async {
      const s = AppSettings(lat: 21.42, lng: 39.82);
      await Notifications.instance.scheduleReminders(s, morning: 'm', evening: 'e', wird: 'w');
      final titlesSeen = rec.named('zonedSchedule').map((c) => (c.arguments as Map)['title']).toSet();
      expect(titlesSeen, containsAll(['m', 'e', 'w']));
      await Notifications.instance.showNow('t', 'b');
      expect(rec.named('show'), isNotEmpty);
    });
  });

  group('Backup files', () {
    test('export and import through files', () async {
      Hive.init(tmp.path);
      final storage = await Storage.initForTest(tmp.path);
      await storage.write('bookmarks', [
        {'r': '1:1', 'c': 'default', 't': DateTime(2026).toIso8601String()},
      ]);
      final file = await Backup.exportToFile(storage, 'secret pass');
      expect(file.path, endsWith('.mishkah'));
      await storage.delete('bookmarks');
      await Backup.importFromFile(storage, file, 'secret pass');
      expect(storage.readList('bookmarks'), isNotEmpty);
      await storage.settle();
      await Hive.close();
    });
  });

  group('Audio downloads', () {
    test('downloads, counts and deletes verse files', () async {
      final r = reciterById('husary');
      var requests = 0;
      final client = MockClient((req) async {
        requests++;
        return http.Response.bytes([1, 2, 3], 200);
      });
      await AudioDownloads.downloadSurah(r, 112, 4, client: client);
      expect(requests, 4);
      expect(await AudioDownloads.downloadedCount(r, 112, 4), 4);
      await AudioDownloads.downloadSurah(r, 112, 4, client: client);
      expect(requests, 4, reason: 'already-downloaded files are skipped');
      final usage = await AudioDownloads.usage();
      expect(usage['husary'], 12);
      await AudioDownloads.deleteSurah(r, 112, 4);
      expect(await AudioDownloads.downloadedCount(r, 112, 4), 0);
      await AudioDownloads.deleteReciter('husary');
      expect(await AudioDownloads.usage(), isEmpty);
    });

    test('HTTP errors surface and cancellation stops early', () async {
      final r = reciterById('alafasy');
      await expectLater(
        AudioDownloads.downloadSurah(r, 1, 7, client: MockClient((_) async => http.Response('', 404))),
        throwsA(isA<HttpException>()),
      );
      var n = 0;
      await AudioDownloads.downloadSurah(r, 2, 10,
          client: MockClient((_) async => http.Response.bytes([0], 200)), cancelled: () => ++n > 3);
      expect(await AudioDownloads.downloadedCount(r, 2, 10), 3);
    });

    test('playback state copyWith', () {
      const s = PlaybackState();
      expect(s.active, isFalse);
      final t = s.copyWith(error: 'x', speed: 1.25);
      expect(t.error, 'x');
      expect(t.copyWith(clearError: true).error, isNull);
      expect(t.speed, 1.25);
    });
  });

  group('Location helpers', () {
    test('nearest city and place labels', () {
      expect(LocationService.nearestCity(45.53, 9.23).nameEn, 'Milano');
      expect(placeLabel(45.53, 9.23, 'ar'), 'ميلانو');
      expect(placeLabel(0, -150, 'en'), '0.000, -150.000');
      expect(cities.map((c) => c.nameEn).toSet().length, cities.length);
    });

    test('LocationResult', () {
      const ok = LocationResult.ok(1, 2);
      expect(ok.ok, isTrue);
      const fail = LocationResult.fail(LocationFailure.denied);
      expect(fail.ok, isFalse);
      expect(fail.lat, isNull);
    });
  });
}
