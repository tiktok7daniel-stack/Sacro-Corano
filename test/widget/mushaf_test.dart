import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:mishkah/app/providers.dart';
import 'package:mishkah/data/quran/mushaf_layout.dart';
import 'package:mishkah/data/quran/word_data.dart';
import 'package:mishkah/domain/settings.dart';
import 'package:mishkah/features/quran/reader_screen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../fake_audio.dart';
import '../fakes.dart';
import '../helpers.dart';

void main() {
  setUpAll(loadAppFonts);
  late TestEnv env;
  late Directory tmp;
  final layout = MushafLayout.parse(File('assets/data/mushaf_lines.json.gz').readAsBytesSync());
  final wbw = WordByWord.parse(File('assets/data/wbw_en.json.gz').readAsBytesSync());

  setUp(() async {
    env = await createEnv(
      settings: const AppSettings(lat: 21.42, lng: 39.82, haptics: false, reduceMotion: true, onboarded: true, autoLocation: false, pageMode: true),
    );
    tmp = Directory.systemTemp.createTempSync('mishkah_mushaf');
    PathProviderPlatform.instance = FakePathProvider(tmp);
    JustAudioPlatform.instance = FakeJustAudio();
    silencePlugins();
  });
  tearDown(() async {
    await env.dispose();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  final overrides = [
    mushafLayoutProvider.overrideWith((ref) async => layout),
    wordByWordProvider.overrideWith((ref) async => wbw),
  ];

  testWidgets('reader opens on mushaf pages: lines as printed, tap and long-press words', (tester) async {
    await pumpScreen(tester, const ReaderScreen(surah: 112), env, overrides: overrides);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);
    expect(find.byType(MushafPage), findsOneWidget);
    expect(find.text('٦٠٤'), findsWidgets);
    expect(find.text('أَحَدٌ'), findsOneWidget, reason: 'each word is its own tappable token');
    // Long press: word meaning.
    final samad = testQuran().text(112, 2).split(' ')[1];
    await tester.longPress(find.text(samad));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text(samad), findsWidgets);
    expect(find.text('the Eternal, the Absolute'), findsOneWidget);
    Navigator.of(tester.element(find.text('the Eternal, the Absolute'))).pop();
    await tester.pump(const Duration(milliseconds: 500));
    // Tap: verse actions.
    await tester.tap(find.text('أَحَدٌ'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('استمع من هنا'), findsOneWidget);
    Navigator.of(tester.element(find.text('استمع من هنا'))).pop();
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('swiping turns to the next page; the bars hide after a moment', (tester) async {
    await pumpScreen(tester, const ReaderScreen(surah: 2), env, overrides: overrides);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('٢'), findsWidgets);
    await tester.pump(const Duration(seconds: 3));
    await tester.fling(find.byType(PageView), const Offset(400, 0), 1500);
    await tester.pumpAndSettle();
    expect(find.text('٣'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a half-way drag eases the leaving page and settles without bouncing', (tester) async {
    await tester.runAsync(() async {
      await env.dispose();
      env = await createEnv(
        settings: const AppSettings(lat: 21.42, lng: 39.82, haptics: false, reduceMotion: false, onboarded: true, autoLocation: false, pageMode: true),
      );
    });
    await pumpScreen(tester, const ReaderScreen(surah: 2), env, overrides: overrides);
    await tester.pump(const Duration(milliseconds: 600));
    final gesture = await tester.startGesture(tester.getCenter(find.byType(PageView)));
    for (var k = 0; k < 6; k++) {
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    final ctl = tester.widget<PageView>(find.byType(PageView)).controller!;
    expect(ctl.page! % 1, greaterThan(0.05), reason: 'the page follows the finger');
    expect(find.byType(Opacity), findsWidgets, reason: 'the leaving page fades a little');
    await gesture.moveBy(const Offset(120, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    final pc = tester.widget<PageView>(find.byType(PageView)).controller!;
    expect(pc.page, closeTo(pc.page!.roundToDouble(), 0.0001), reason: 'rests exactly on a page');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('choosing another surah from the title jumps to its page', (tester) async {
    await pumpScreen(tester, const ReaderScreen(surah: 112), env, overrides: overrides);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('٦٠٤'), findsWidgets);
    await tester.tap(find.byIcon(Icons.expand_more_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('البقرة').last);
    await tester.pumpAndSettle();
    final pc = tester.widget<PageView>(find.byType(PageView)).controller!;
    expect(pc.page!.round() + 1, 2, reason: 'Al-Baqarah starts on page 2');
    expect(find.text('٢'), findsWidgets);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 3));
  });
}
