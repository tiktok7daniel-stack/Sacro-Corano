import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:mishkah/app/providers.dart';
import 'package:mishkah/core/theme/app_theme.dart';
import 'package:mishkah/data/local/storage.dart';
import 'package:mishkah/data/quran/mushaf_layout.dart';
import 'package:mishkah/data/quran/quran_data.dart';
import 'package:mishkah/data/quran/word_data.dart';
import 'package:mishkah/domain/settings.dart';

import '../helpers.dart';

void main() {
  final layout = MushafLayout.parse(File('assets/data/mushaf_lines.json.gz').readAsBytesSync());

  test('604 pages of 15 lines (8 on the first two)', () {
    expect(layout.page(1), hasLength(8));
    expect(layout.page(2), hasLength(8));
    for (var p = 3; p <= 604; p++) {
      expect(layout.page(p), hasLength(15), reason: 'page $p');
    }
    expect(layout.page(0), isEmpty);
    expect(layout.page(605), isEmpty);
    expect(layout.page(1).first.isHeader, isTrue);
    expect(layout.page(1).first.surah, 1);
    expect(layout.page(2)[1].basmala, isTrue);
    expect(layout.page(187).first.surah, 9, reason: 'At-Tawbah has no basmala');
    expect(layout.page(187)[1].isWords, isTrue);
  });

  test('every word of the text is on exactly one line, in order, and pages agree with the index', () {
    final q = testQuran();
    final seen = <int, List<int>>{};
    final markers = <int>{};
    for (var p = 1; p <= 604; p++) {
      for (final line in layout.page(p)) {
        for (var i = 0; i < line.length; i++) {
          final key = line.surahAt(i) * 1000 + line.ayahAt(i);
          if (line.wordAt(i) < 0) {
            markers.add(key);
            // The verse ends on the page the index says it is on.
            expect(q.pageOf(line.surahAt(i), line.ayahAt(i)), p, reason: '${line.surahAt(i)}:${line.ayahAt(i)}');
          } else {
            (seen[key] ??= []).add(line.wordAt(i));
          }
        }
      }
    }
    for (final s in q.surahs) {
      for (var a = 1; a <= s.ayahCount; a++) {
        final n = verseWords(q.text(s.number, a)).length;
        expect(seen[s.number * 1000 + a], List.generate(n, (i) => i), reason: '${s.number}:$a');
        expect(markers, contains(s.number * 1000 + a));
      }
    }
  });

  test('open tanween uses the standard code points the font can draw', () {
    expect(QuranData.standardTanween('عَذَابٞ'), 'عَذَابࣱ');
    expect(QuranData.standardTanween('ٖٗ'), 'ࣰࣲ');
    final all = testQuran().rawText.expand((s) => s).join();
    expect(all.contains('ٞ'), isFalse);
    expect(all.contains('ٗ'), isFalse);
    expect(all.contains('ٖ'), isFalse);
  });

  group('reader defaults', () {
    late Directory dir;
    late Storage storage;
    setUp(() async {
      dir = await Directory.systemTemp.createTemp('mishkah_mig');
      storage = await Storage.initForTest(dir.path);
    });
    tearDown(() async {
      await storage.settle();
      await Hive.close();
      await dir.delete(recursive: true);
    });

    test('existing readers move to mushaf pages with a white page, once', () async {
      await storage.writeSettings(const AppSettings(pageMode: false, readingTheme: AppThemeKind.night, onboarded: true).toJson());
      var c = ProviderContainer(overrides: [storageProvider.overrideWithValue(storage)]);
      expect(c.read(settingsProvider).pageMode, isTrue);
      expect(c.read(settingsProvider).readingTheme, AppThemeKind.light);
      c.read(settingsProvider.notifier).update((s) => s.copyWith(pageMode: false));
      c.dispose();
      await storage.settle();
      c = ProviderContainer(overrides: [storageProvider.overrideWithValue(storage)]);
      expect(c.read(settingsProvider).pageMode, isFalse, reason: 'their own choice afterwards is kept');
      c.dispose();
      expect(ReadingPalette.light.page.toARGB32(), 0xFFFFFFFF);
      expect(ReadingPalette.light.ink.toARGB32(), 0xFF000000);
    });
  });
}
