import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../core/l10n/strings.dart';
import '../domain/prayer_times.dart';
import '../domain/qibla.dart';
import '../domain/settings.dart';
import '../features/onboarding/onboarding_sheet.dart';
import '../services/home_widget_sync.dart';
import '../services/location.dart';
import '../services/notifications.dart';
import 'providers.dart';

/// Work done once the first frame is on screen, so start-up stays fast.
abstract final class Bootstrap {
  static Future<void> afterFirstFrame(BuildContext context, WidgetRef ref) async {
    final s = ref.read(settingsProvider);
    if (!s.onboarded) {
      await showOnboarding(context, ref);
      if (!context.mounted) return;
    } else if (s.autoLocation) {
      try {
        await _travelCheck(context, ref);
      } catch (e) {
        debugPrint('Travel check skipped: $e');
      }
      if (!context.mounted) return;
    }
    await reschedule(context, ref, onlyIfChanged: true);
  }

  /// Travel mode: if the device moved more than 50 km from the saved place,
  /// offer to update prayer times (never changes silently).
  static Future<void> _travelCheck(BuildContext context, WidgetRef ref) async {
    final s = ref.read(settingsProvider);
    final perm = await Geolocator.checkPermission();
    if (perm != LocationPermission.always && perm != LocationPermission.whileInUse) return;
    final pos = await Geolocator.getLastKnownPosition();
    if (pos == null || !s.hasLocation) return;
    final km = distanceKm(s.lat!, s.lng!, pos.latitude, pos.longitude);
    if (km < 50 || !context.mounted) return;
    final place = placeLabel(pos.latitude, pos.longitude, context.lang);
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 10),
      content: Text(context.tr('travel_detected', {'place': place})),
      action: SnackBarAction(
        label: context.tr('update'),
        onPressed: () {
          ref.read(settingsProvider.notifier).update((x) => x.copyWith(lat: pos.latitude, lng: pos.longitude, placeName: place));
          reschedule(context, ref);
        },
      ),
    ));
  }

  static Timer? _debounce;

  /// What the schedule depends on; when it is unchanged (same day, same
  /// settings and language) a launch skips the ~100 platform calls.
  static String scheduleSignature(AppSettings s, String lang, DateTime now) => jsonEncode([
        '${now.year}-${now.month}-${now.day}',
        lang,
        s.lat,
        s.lng,
        s.calcMethod,
        s.madhab,
        s.highLatRule,
        s.prayerOffsets,
        s.adhanEnabled,
        s.preAdhanMinutes,
        s.azkarReminders,
        s.wirdReminderHour,
        s.adhanSound,
        s.iqamaAlert,
        s.iqamaMinutes,
        s.ramadanReminders,
        s.kahfReminder,
        s.salawatReminder,
        s.whiteDaysReminder,
        s.monThuReminder,
        s.occasionFastReminder,
      ]);

  /// Re-schedules notifications and refreshes the home-screen widget.
  /// Rapid changes (toggling several bells) are coalesced into one run.
  static Future<void> reschedule(BuildContext context, WidgetRef ref, {bool onlyIfChanged = false}) {
    final s = ref.read(settingsProvider);
    final lang = context.lang;
    final storage = ref.read(storageProvider);
    final sig = scheduleSignature(s, lang, DateTime.now());
    if (onlyIfChanged && storage.read<String>('scheduleSig') == sig) return Future.value();
    final titles = {for (final p in PrayerName.values) p: context.tr('adhan_title_${p.name}')};
    final body = context.tr('adhan_body');
    final morning = context.tr('reminder_morning');
    final evening = context.tr('reminder_evening');
    final wird = context.tr('reminder_wird');
    final iqama = context.tr('reminder_iqama');
    final smart = SmartTexts(
      kahf: context.tr('reminder_kahf'),
      salawat: context.tr('reminder_salawat'),
      whiteDays: context.tr('reminder_white_days'),
      monThu: context.tr('reminder_mon_thu'),
      arafah: context.tr('reminder_arafah'),
      ashura: context.tr('reminder_ashura'),
      suhoor: context.tr('reminder_suhoor'),
      iftar: context.tr('reminder_iftar'),
    );
    Future<void> run() async {
      try {
        await Notifications.instance.schedulePrayers(s, titles: titles, body: body, iqama: iqama);
        await Notifications.instance.scheduleReminders(s, morning: morning, evening: evening, wird: wird);
        await Notifications.instance.scheduleSmart(s, smart);
        await storage.write('scheduleSig', sig);
      } catch (e) {
        debugPrint('Scheduling failed: $e');
      }
      try {
        await HomeWidgetSync.update(ref, s, lang);
      } catch (e) {
        // The calling widget may be gone after the debounce delay.
        debugPrint('Widget refresh skipped: $e');
      }
    }

    if (onlyIfChanged) return run();
    final done = Completer<void>();
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => run().whenComplete(done.complete));
    return done.future;
  }
}

/// Human readable place: nearest known city within 60 km, else coordinates.
String placeLabel(double lat, double lng, String lang) {
  final c = LocationService.nearestCity(lat, lng);
  if (distanceKm(lat, lng, c.lat, c.lng) <= 60) return c.name(lang);
  return '${lat.toStringAsFixed(3)}, ${lng.toStringAsFixed(3)}';
}

/// Applies a fresh GPS fix to settings; returns a user-facing error key.
Future<String?> useCurrentLocation(WidgetRef ref, String lang) async {
  final r = await LocationService.current();
  if (!r.ok) {
    return switch (r.failure!) {
      LocationFailure.serviceDisabled => 'loc_service_off',
      LocationFailure.denied => 'loc_denied',
      LocationFailure.deniedForever => 'loc_denied_forever',
      LocationFailure.timeout => 'loc_timeout',
    };
  }
  ref.read(settingsProvider.notifier).update(
        (AppSettings s) => s.copyWith(lat: r.lat, lng: r.lng, placeName: placeLabel(r.lat!, r.lng!, lang), autoLocation: true),
      );
  return null;
}
