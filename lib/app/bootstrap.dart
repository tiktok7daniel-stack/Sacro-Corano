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
    await reschedule(context, ref);
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

  /// Re-schedules notifications and refreshes the home-screen widget.
  static Future<void> reschedule(BuildContext context, WidgetRef ref) async {
    final s = ref.read(settingsProvider);
    final titles = {for (final p in PrayerName.values) p: context.tr('adhan_title_${p.name}')};
    final body = context.tr('adhan_body');
    final morning = context.tr('reminder_morning');
    final evening = context.tr('reminder_evening');
    final wird = context.tr('reminder_wird');
    final lang = context.lang;
    try {
      await Notifications.instance.schedulePrayers(s, titles: titles, body: body);
      await Notifications.instance.scheduleReminders(s, morning: morning, evening: evening, wird: wird);
    } catch (e) {
      debugPrint('Scheduling failed: $e');
    }
    await HomeWidgetSync.update(ref, s, lang);
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
