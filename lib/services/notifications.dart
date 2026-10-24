import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/utils/hijri.dart';
import '../domain/prayer_times.dart';
import '../domain/settings.dart';

/// Localised texts for the smart reminders, filled in by the caller.
class SmartTexts {
  const SmartTexts({
    this.kahf = '',
    this.salawat = '',
    this.whiteDays = '',
    this.monThu = '',
    this.arafah = '',
    this.ashura = '',
    this.suhoor = '',
    this.iftar = '',
    this.iqama = '',
  });
  final String kahf;
  final String salawat;
  final String whiteDays;
  final String monThu;
  final String arafah;
  final String ashura;
  final String suhoor;
  final String iftar;
  final String iqama;
}

/// Schedules prayer, azkar and wird reminders as exact local alarms, so
/// they fire without any server or network connection.
class Notifications {
  Notifications._();
  static final instance = Notifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _prayerChannel = AndroidNotificationDetails(
    'prayer_times',
    'مواقيت الصلاة',
    channelDescription: 'تنبيه دخول وقت الصلاة',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    icon: 'ic_stat_mishkah',
  );
  static const _reminderChannel = AndroidNotificationDetails(
    'reminders',
    'التذكيرات',
    channelDescription: 'أذكار الصباح والمساء والورد اليومي',
    importance: Importance.defaultImportance,
    icon: 'ic_stat_mishkah',
  );

  /// Adhan notification channel for the chosen sound. Android fixes a
  /// channel's sound when it is created, so each sound has its own channel.
  static AndroidNotificationDetails adhanChannel(String sound) => switch (sound) {
        'full' || 'short' => AndroidNotificationDetails(
            'adhan_$sound',
            sound == 'full' ? 'الأذان (كامل)' : 'الأذان (قصير)',
            channelDescription: 'الأذان عند دخول وقت الصلاة',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            icon: 'ic_stat_mishkah',
            sound: RawResourceAndroidNotificationSound('mishkah_adhan_$sound'),
            audioAttributesUsage: AudioAttributesUsage.alarm,
            actions: const [AndroidNotificationAction('stop', 'إيقاف الأذان', cancelNotification: true)],
          ),
        'silent' => const AndroidNotificationDetails(
            'prayer_silent',
            'تنبيه صامت',
            channelDescription: 'إشعار دخول الوقت دون صوت',
            importance: Importance.high,
            playSound: false,
            icon: 'ic_stat_mishkah',
          ),
        _ => _prayerChannel,
      };

  Future<void> initTimezones() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (e) {
      debugPrint('Timezone lookup failed, using UTC: $e');
      tz.setLocalLocation(tz.UTC);
    }
  }

  Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_stat_mishkah')),
    );
    _ready = true;
  }

  /// Asks for POST_NOTIFICATIONS (Android 13+) and exact alarms (Android 12+).
  Future<bool> requestPermissions() async {
    await _init();
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final granted = await android?.requestNotificationsPermission() ?? true;
    await android?.requestExactAlarmsPermission();
    return granted;
  }

  /// Cancels only the pending ids in [base, base + count): one query
  /// instead of a platform call per possible id.
  Future<void> _cancelRange(int base, int count) async {
    final pending = await _plugin.pendingNotificationRequests();
    for (final r in pending) {
      if (r.id >= base && r.id < base + count) await _plugin.cancel(id: r.id);
    }
  }

  static const _prayerIdBase = 1000;
  static const _reminderIdBase = 5000;

  /// Re-schedules the next [days] days of prayer alerts. Called on launch,
  /// whenever settings change and when the location changes (travel mode).
  Future<void> schedulePrayers(AppSettings s, {int days = 14, required Map<PrayerName, String> titles, required String body, String iqama = ''}) async {
    await _init();
    await _cancelRange(_prayerIdBase, days * 6 * 3);
    final adhan = adhanChannel(s.adhanSound);
    if (!s.hasLocation) return;
    final calc = PrayerCalculator(s);
    final now = DateTime.now();
    var id = _prayerIdBase;
    for (var d = 0; d < days; d++) {
      final day = calc.forDate(now.add(Duration(days: d)));
      for (final p in PrayerName.values) {
        if (!p.isFard || s.adhanEnabled[p.name] != true) continue;
        final at = day[p];
        if (at.isAfter(now)) {
          await _schedule(id++, at, titles[p]!, body, adhan);
        }
        if (s.iqamaAlert && iqama.isNotEmpty) {
          final iq = at.add(Duration(minutes: s.iqamaMinutes));
          if (iq.isAfter(now)) await _schedule(id++, iq, iqama, titles[p]!, _reminderChannel);
        }
        if (s.preAdhanMinutes > 0) {
          final pre = at.subtract(Duration(minutes: s.preAdhanMinutes));
          if (pre.isAfter(now)) await _schedule(id++, pre, titles[p]!, '⏳ ${s.preAdhanMinutes}′', _reminderChannel);
        }
      }
    }
  }

  /// Morning / evening azkar after Fajr and Asr, plus the daily wird.
  Future<void> scheduleReminders(AppSettings s, {required String morning, required String evening, required String wird}) async {
    await _init();
    await _cancelRange(_reminderIdBase, 30);
    final now = DateTime.now();
    var id = _reminderIdBase;
    if (s.azkarReminders && s.hasLocation) {
      final calc = PrayerCalculator(s);
      for (var d = 0; d < 7; d++) {
        final day = calc.forDate(now.add(Duration(days: d)));
        final m = day[PrayerName.fajr].add(const Duration(minutes: 20));
        final e = day[PrayerName.asr].add(const Duration(minutes: 20));
        if (m.isAfter(now)) await _schedule(id++, m, morning, '', _reminderChannel);
        if (e.isAfter(now)) await _schedule(id++, e, evening, '', _reminderChannel);
      }
    }
    var w = DateTime(now.year, now.month, now.day, s.wirdReminderHour);
    if (!w.isAfter(now)) w = w.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: id,
      scheduledDate: tz.TZDateTime.from(w, tz.local),
      notificationDetails: const NotificationDetails(android: _reminderChannel),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      title: wird,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  static const _smartIdBase = 7000;

  /// Friday Al-Kahf and salawat, the eve of recommended fasts (white days,
  /// Monday/Thursday, Arafah, Tasu'a/Ashura) and Ramadan suhoor/iftar, for
  /// the next [days] days. Each kind has its own switch in settings.
  Future<void> scheduleSmart(AppSettings s, SmartTexts t, {int days = 8, DateTime? from}) async {
    await _init();
    await _cancelRange(_smartIdBase, 100);
    final now = from ?? DateTime.now();
    final calc = s.hasLocation ? PrayerCalculator(s) : null;
    var id = _smartIdBase;
    Future<void> at(DateTime when, String title) async {
      if (title.isEmpty || !when.isAfter(now) || id >= _smartIdBase + 100) return;
      await _schedule(id++, when, title, '', _reminderChannel);
    }

    for (var d = 0; d < days; d++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: d));
      final tomorrow = HijriDate.fromGregorian(day.add(const Duration(days: 1)), offsetDays: s.hijriOffset);
      final today = HijriDate.fromGregorian(day, offsetDays: s.hijriOffset);
      final evening = DateTime(day.year, day.month, day.day, 21);
      if (day.weekday == DateTime.friday) {
        if (s.kahfReminder) await at(DateTime(day.year, day.month, day.day, 10), t.kahf);
        if (s.salawatReminder) await at(DateTime(day.year, day.month, day.day, 16), t.salawat);
      }
      // Fasting reminders on the eve; none for the days of Eid or Tashriq.
      final noFast = (tomorrow.month == 10 && tomorrow.day == 1) || (tomorrow.month == 12 && tomorrow.day >= 10 && tomorrow.day <= 13);
      if (!noFast && tomorrow.month != 9) {
        if (s.occasionFastReminder && tomorrow.month == 12 && tomorrow.day == 9) {
          await at(evening, t.arafah);
        } else if (s.occasionFastReminder && tomorrow.month == 1 && (tomorrow.day == 9 || tomorrow.day == 10)) {
          await at(evening, t.ashura);
        } else if (s.whiteDaysReminder && tomorrow.day >= 13 && tomorrow.day <= 15) {
          await at(evening, t.whiteDays);
        } else if (s.monThuReminder && (day.weekday == DateTime.sunday || day.weekday == DateTime.wednesday)) {
          await at(evening, t.monThu);
        }
      }
      if (s.ramadanReminders && today.month == 9 && calc != null) {
        final times = calc.forDate(day);
        await at(times[PrayerName.fajr].subtract(const Duration(minutes: 40)), t.suhoor);
        await at(times[PrayerName.maghrib], t.iftar);
      }
    }
  }

  /// Plays the chosen adhan now, so the user can hear it.
  Future<void> testAdhan(String sound, String title, String body) async {
    await _init();
    await _plugin.show(id: 9998, title: title, body: body, notificationDetails: NotificationDetails(android: adhanChannel(sound)));
  }

  Future<void> showNow(String title, String body) async {
    await _init();
    await _plugin.show(id: 9999, title: title, body: body, notificationDetails: const NotificationDetails(android: _reminderChannel));
  }

  Future<void> _schedule(int id, DateTime at, String title, String body, AndroidNotificationDetails channel) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: NotificationDetails(android: channel),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        title: title,
        body: body,
      );
    } catch (_) {
      // Exact alarms denied: fall back to inexact delivery.
      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: tz.TZDateTime.from(at, tz.local),
        notificationDetails: NotificationDetails(android: channel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: title,
        body: body,
      );
    }
  }
}
