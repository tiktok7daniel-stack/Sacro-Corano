import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';

import '../app/providers.dart';
import '../core/utils/arabic.dart';
import '../domain/daily_content.dart';
import '../domain/prayer_times.dart';
import '../domain/settings.dart';

/// Pushes today's data to the native Android home-screen widget
/// (android/app/src/main/kotlin/.../MishkahWidgetProvider.kt).
abstract final class HomeWidgetSync {
  static const androidProvider = 'MishkahWidgetProvider';

  static Future<void> update(WidgetRef ref, AppSettings s, String lang) async {
    try {
      final quran = await ref.read(quranProvider.future);
      final verse = verseOfTheDay(DateTime.now());
      final text = quran.text(verse.surah, verse.ayah);
      await HomeWidget.saveWidgetData<String>('verse_text', text);
      await HomeWidget.saveWidgetData<String>('verse_ref', '${quran.surah(verse.surah).nameAr} · ${toArabicDigits(verse.ayah)}');

      final calc = s.hasLocation ? PrayerCalculator(s) : null;
      if (calc != null) {
        final today = calc.forDate(DateTime.now());
        String fmt(DateTime t) {
          final h = t.hour.toString().padLeft(2, '0');
          final m = t.minute.toString().padLeft(2, '0');
          return lang == 'ar' ? toArabicDigits('$h:$m') : '$h:$m';
        }

        for (final p in PrayerName.values) {
          await HomeWidget.saveWidgetData<String>('time_${p.name}', fmt(today[p]));
        }
        final (next, at) = calc.next(DateTime.now());
        await HomeWidget.saveWidgetData<String>('next_name', next.name);
        await HomeWidget.saveWidgetData<int>('next_epoch', at.millisecondsSinceEpoch);
      }
      await HomeWidget.saveWidgetData<String>('lang', lang);
      await HomeWidget.updateWidget(androidName: androidProvider);
    } catch (e) {
      debugPrint('Widget update skipped: $e');
    }
  }
}
