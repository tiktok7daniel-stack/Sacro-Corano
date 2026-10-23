import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:mishkah/app/providers.dart';
import 'package:mishkah/domain/quran_models.dart';
import 'package:mishkah/features/audio/mini_player.dart';
import 'package:mishkah/features/bookmarks/bookmarks_screen.dart';
import 'package:mishkah/features/khatma/khatma_screen.dart';
import 'package:mishkah/features/quran/focus_listen_screen.dart';
import 'package:mishkah/features/quran/quran_index_screen.dart';
import 'package:mishkah/features/quran/reader_screen.dart';
import 'package:mishkah/features/tasbih/tasbih_screen.dart';
import 'package:mishkah/services/audio.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../fake_audio.dart';
import '../fakes.dart';
import '../helpers.dart';

void main() {
  setUpAll(loadAppFonts);
  late TestEnv env;
  late Directory tmp;
  late FakeJustAudio audio;

  setUp(() async {
    env = await createEnv();
    tmp = Directory.systemTemp.createTempSync('mishkah_inter');
    PathProviderPlatform.instance = FakePathProvider(tmp);
    JustAudioPlatform.instance = audio = FakeJustAudio();
    silencePlugins();
  });
  tearDown(() async {
    await env.dispose();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  ProviderContainer containerOf(WidgetTester t, Type type) => ProviderScope.containerOf(t.element(find.byType(type).first));

  // Playback mixes real I/O with fake-async timers: alternate both.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('playing a surah drives the mini player, highlight and controls', (tester) async {
    await pumpScreen(tester, const ReaderScreen(surah: 112), env);
    await tester.tap(find.byIcon(Icons.play_circle_outline_rounded));
    await settle(tester);
    final player = audio.last;
    // Basmala + 4 verses, streamed from EveryAyah.
    expect(player.uris.length, 5);
    expect(player.uris.first, contains('everyayah.com/data/Alafasy_128kbps/001001.mp3'));
    expect(player.playing, isTrue);
    expect(find.byType(MiniPlayer), findsWidgets);
    player.advance();
    player.advance();
    await settle(tester);
    final c = containerOf(tester, ReaderScreen);
    expect(c.read(audioProvider).current, const AyahRef(112, 2));
    expect(c.read(activityProvider.notifier).today().ayahsRead, greaterThanOrEqualTo(1));

    await tester.tap(find.byTooltip('السرعة'));
    await settle(tester);
    expect(player.speed, 1.25);
    await tester.tap(find.byTooltip('إيقاف مؤقت'));
    await settle(tester);
    expect(player.playing, isFalse);

    await c.read(audioProvider.notifier).seekToAyah(const AyahRef(112, 4));
    await settle(tester);
    expect(player.index, 4);
    c.read(audioProvider.notifier).setRepeatEach(3);
    expect(c.read(audioProvider).repeatEach, 3);

    await tester.tap(find.byTooltip('إيقاف'));
    await settle(tester);
    expect(c.read(audioProvider).active, isFalse);
  });

  testWidgets('focused listening shows only the current verse', (tester) async {
    await pumpScreen(tester, const FocusListenScreen(start: AyahRef(1, 1)), env);
    await settle(tester);
    expect(audio.last.uris.length, 7, reason: 'al-Fatiha has no separate basmala');
    expect(find.textContaining(testQuran().text(1, 1).split(' ').last), findsWidgets);
    await tester.tap(find.byTooltip('التالي'));
    await settle(tester);
    await tester.tap(find.byTooltip('السابق'));
    await settle(tester);
    await tester.tap(find.byIcon(Icons.pause_rounded));
    await settle(tester);
    expect(audio.last.playing, isFalse);
  });

  testWidgets('downloaded verses play from local files', (tester) async {
    final dir = Directory('${tmp.path}/docs/audio/alafasy')..createSync(recursive: true);
    for (var a = 1; a <= 3; a++) {
      File('${dir.path}/108${a.toString().padLeft(3, '0')}.mp3').writeAsBytesSync([0]);
    }
    await pumpScreen(tester, const ReaderScreen(surah: 108), env);
    final c = containerOf(tester, ReaderScreen);
    await tester.runAsync(() => c.read(audioProvider.notifier).playSurah(108, from: 2));
    await settle(tester);
    expect(audio.last.uris.first, startsWith('file://'));
    expect(audio.last.uris.length, 2, reason: 'from verse 2: no basmala');
  });

  testWidgets('verse actions: reflect, repeat, memorise, copy', (tester) async {
    await pumpScreen(tester, const ReaderScreen(surah: 103), env);
    await tester.tap(find.byType(InkWell).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تدبّر'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'الوقت رأس المال');
    await tester.tap(find.widgetWithText(FilterChip, 'الصبر'));
    await tester.pump();
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    final c = containerOf(tester, ReaderScreen);
    expect(c.read(reflectionsProvider).single.tags, ['sabr']);

    await tester.tap(find.byType(InkWell).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('للحفظ'));
    await tester.pumpAndSettle();
    expect(c.read(hifzProvider), isNotEmpty);

    await tester.tap(find.byType(InkWell).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('كرّر الآية'));
    await settle(tester);
    expect(audio.last.uris.length, 5, reason: 'one verse × 5 repeats');

    await tester.tap(find.byType(InkWell).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نسخ'));
    // Snackbars queue: the "added to memorisation" one shows first.
    await tester.pump(const Duration(seconds: 5));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('تم النسخ'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('quran index juz and hizb tabs open the reader', (tester) async {
    await pumpScreen(tester, const Scaffold(body: QuranIndexScreen()), env);
    await tester.tap(find.text('الجزء'));
    await tester.pumpAndSettle();
    expect(find.text('الجزء ٣٠'), findsNothing, reason: 'lazy grid, first items only');
    await tester.tap(find.text('الجزء ٢'));
    await tester.pumpAndSettle();
    expect(find.byType(ReaderScreen), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('الأحزاب'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    expect(find.byType(ReaderScreen), findsOneWidget);
  });

  testWidgets('tasbih: custom dhikr, goal and history', (tester) async {
    await pumpScreen(tester, const TasbihScreen(), env);
    await tester.tap(find.byTooltip('ذكر جديد'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'يا حي يا قيوم');
    await tester.enterText(find.byType(TextField).last, '3');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('يا حي يا قيوم'), findsWidgets);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('/ ٣'));
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(find.text('الدورات: ١'), findsOneWidget);
    await tester.tap(find.text('اليوم'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('٣٣'));
    await tester.pumpAndSettle();
    expect(containerOf(tester, TasbihScreen).read(settingsProvider).tasbihGoal, 33);
    await tester.tap(find.text('السجل'));
    await tester.pumpAndSettle();
    expect(find.text('آخر ١٤ يومًا'), findsOneWidget);
  });

  testWidgets('khatma: busy days and finishing celebrates', (tester) async {
    await pumpScreen(tester, const KhatmaScreen(), env);
    await tester.tap(find.widgetWithText(FilterChip, 'الجمعة'));
    await tester.tap(find.text('ابدأ الختمة'));
    await tester.pumpAndSettle();
    final c = containerOf(tester, KhatmaScreen);
    expect(c.read(khatmaProvider)!.busyWeekdays, {5});
    await tester.tap(find.text('سجّل تقدّمك'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '604');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('ختمت القرآن!'), findsOneWidget);
    await tester.tap(find.text('الحمد لله'));
    await tester.pumpAndSettle();
    expect(c.read(khatmaProvider)!.done, isTrue);
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ختمة جديدة'));
    await tester.pumpAndSettle();
    expect(c.read(khatmaProvider)!.completedCount, 1);
  });

  testWidgets('bookmarks move to a new collection', (tester) async {
    await pumpScreen(tester, const BookmarksScreen(), env);
    final c = containerOf(tester, BookmarksScreen);
    c.read(bookmarksProvider.notifier).toggle(const AyahRef(1, 5));
    await tester.pump();
    await tester.tap(find.byTooltip('نقل إلى'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('مجموعة جديدة').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'دعاء');
    await tester.tap(find.text('حفظ'));
    await tester.pumpAndSettle();
    expect(c.read(bookmarksProvider).single.collection, 'دعاء');
    expect(find.widgetWithText(ChoiceChip, 'دعاء'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });

  test('playback state defaults', () {
    expect(const PlaybackState().repeatEach, 1);
  });
}
