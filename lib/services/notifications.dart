import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/prayer_times.dart';
import '../domain/settings.dart';

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

  static const _prayerIdBase = 1000;
  static const _reminderIdBase = 5000;

  /// Re-schedules the next [days] days of prayer alerts. Called on launch,
  /// whenever settings change and when the location changes (travel mode).
  Future<void> schedulePrayers(AppSettings s, {int days = 7, required Map<PrayerName, String> titles, required String body}) async {
    await _init();
    for (var i = 0; i < days * 6 * 2; i++) {
      await _plugin.cancel(id: _prayerIdBase + i);
    }
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
          await _schedule(id++, at, titles[p]!, body, _prayerChannel);
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
    for (var i = 0; i < 30; i++) {
      await _plugin.cancel(id: _reminderIdBase + i);
    }
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
