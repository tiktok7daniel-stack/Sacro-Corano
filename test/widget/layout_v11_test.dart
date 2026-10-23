import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:mishkah/app/providers.dart';
import 'package:mishkah/core/widgets/common.dart';
import 'package:mishkah/data/hadith_repository.dart';
import 'package:mishkah/domain/quran_models.dart';
import 'package:mishkah/features/azkar/azkar_screen.dart';
import 'package:mishkah/features/favorites/favorites_screen.dart';
import 'package:mishkah/features/hadith/hadith_screen.dart';
import 'package:mishkah/features/home/home_screen.dart';
import 'package:mishkah/features/prayer/calendar_screens.dart';
import 'package:mishkah/features/prayer/prayer_screen.dart';
import 'package:mishkah/features/quran/verse_journey.dart';
import 'package:mishkah/features/radio/radio_screen.dart';
import 'package:mishkah/features/sadaqa/sadaqa_screen.dart';
import 'package:mishkah/features/sira/sira_screen.dart';
import 'package:mishkah/features/tafsir/audio_tafsir_screen.dart';
import 'package:mishkah/features/videos/videos_screen.dart';
import 'package:mishkah/services/audio.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../fake_audio.dart';
import '../fakes.dart';
import '../helpers.dart';

void main() {
  setUpAll(loadAppFonts);
  late TestEnv env;
  late Directory tmp;

  setUp(() async {
    env = await createEnv();
    tmp = Directory.systemTemp.createTempSync('mishkah_v11');
    PathProviderPlatform.instance = FakePathProvider(tmp);
    JustAudioPlatform.instance = FakeJustAudio();
    silencePlugins();
  });
  tearDown(() async {
    await env.dispose();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  ProviderContainer containerOf(WidgetTester t, Type type) => ProviderScope.containerOf(t.element(find.byType(type).first));
  Finder scrollable() => find.byType(Scrollable).first;

  testWidgets('home follows the new section order', (tester) async {
    await pumpScreen(tester, const Scaffold(body: HomeScreen()), env);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('أسبوعك'), findsOneWidget);
    final counter = find.descendant(of: find.byType(TipsCard), matching: find.textContaining('/'));
    await tester.scrollUntilVisible(counter, 300, scrollable: scrollable());
    final before = tester.widget<Text>(counter).data;
    await tester.tap(find.descendant(of: find.byType(TipsCard), matching: find.byType(IconButton)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.widget<Text>(counter).data, isNot(before));
    // A very tall window lays every section out at once.
    tester.view.physicalSize = const Size(1170, 18000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final headers = [for (final e in find.byType(SectionHeader).evaluate()) (e.widget as SectionHeader).title];
    expect(headers, [
      'إشراقات اليوم',
      'كل يوم',
      'اسمع وسبّح',
      'أذكار اليوم',
      'حين تحتاجها',
      'اقرأ وشاهد',
      'تدبّر وسيرة',
      'للعائلة والمسجد',
    ]);
    expect(find.text('التفسير المسموع'), findsOneWidget);
    expect(find.text('السيرة النبوية'), findsOneWidget);
    expect(find.text('الإذاعات'), findsOneWidget);
    expect(find.text('التقويم الهجري'), findsOneWidget);
  });

  testWidgets('home header opens favourites and the azkar carousel flags the time', (tester) async {
    await pumpScreen(tester, const Scaffold(body: HomeScreen()), env);
    expect(AzkarCarousel.nowCategory(DateTime(2026, 1, 1, 7)), 'أذكار الصباح');
    expect(AzkarCarousel.nowCategory(DateTime(2026, 1, 1, 17)), 'أذكار المساء');
    expect(AzkarCarousel.nowCategory(DateTime(2026, 1, 1, 23)), 'أذكار النوم');
    expect(AzkarCarousel.nowCategory(DateTime(2026, 1, 1, 13)), isNull);
    await tester.tap(find.byTooltip('المفضلة'));
    await tester.pumpAndSettle();
    expect(find.byType(FavoritesScreen), findsOneWidget);
  });

  testWidgets('week card counts logged prayers', (tester) async {
    await pumpScreen(tester, const Scaffold(body: SingleChildScrollView(child: WeekCard())), env);
    final c = containerOf(tester, WeekCard);
    c.read(activityProvider.notifier).togglePrayer('fajr');
    c.read(activityProvider.notifier).togglePrayer('dhuhr');
    await tester.pump();
    expect(find.text('٢/٣٥'), findsOneWidget);
    expect(find.text('١/٧'), findsOneWidget);
  });

  testWidgets('occasion card counts down', (tester) async {
    await pumpScreen(tester, const Scaffold(body: OccasionCard()), env);
    expect(find.byIcon(Icons.nightlight_round), findsOneWidget);
    await tester.tap(find.byType(OccasionCard));
    await tester.pumpAndSettle();
    expect(find.byType(HijriCalendarScreen), findsOneWidget);
  });

  testWidgets('azkar tab: hisn hero, index search, prayer adhkar and favourites', (tester) async {
    await pumpScreen(tester, const AzkarScreen(standalone: true), env);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('حصن المسلم'), findsOneWidget);
    expect(find.text('تصنيفات الأذكار'), findsOneWidget);
    await tester.tap(find.text('افتح الكتاب'));
    await tester.pumpAndSettle();
    expect(find.byType(HisnIndexScreen), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'السفر');
    await tester.pump();
    expect(find.text('دعاء السفر'), findsOneWidget);
    await tester.tap(find.text('دعاء السفر'));
    await tester.pumpAndSettle();
    expect(find.byType(AzkarReaderScreen), findsOneWidget);
    await tester.tap(find.byTooltip('حفظ').first);
    await tester.pump();
    final c = containerOf(tester, AzkarReaderScreen);
    expect(c.read(favoritesProvider).single.type, 'zikr');
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('أذكار داخل الصلاة').hitTestable(), 300, scrollable: scrollable());
    await tester.tap(find.text('أذكار داخل الصلاة'));
    await tester.pumpAndSettle();
    final reader = tester.widget<AzkarReaderScreen>(find.byType(AzkarReaderScreen));
    expect(reader.category.items.length, greaterThan(30));
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('الرقية الشرعية').hitTestable(), 300, scrollable: scrollable());
    await tester.tap(find.text('الرقية الشرعية'));
    await tester.pumpAndSettle();
    expect(tester.widget<AzkarReaderScreen>(find.byType(AzkarReaderScreen)).category.items.length, 33);
  });

  testWidgets('prayer tab: next prayer, month table, calendar and location sheet', (tester) async {
    await pumpScreen(tester, const PrayerScreen(standalone: true), env);
    expect(find.text('الصلاة القادمة'), findsWidgets);
    expect(find.text('مكة المكرمة'), findsOneWidget);
    await tester.tap(find.text('مكة المكرمة'));
    await tester.pumpAndSettle();
    expect(find.text('موقعي الحالي'), findsOneWidget);
    await tester.tap(find.text('اختر مدينة').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).at(2));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('التالي').first);
    await tester.pump();
    await tester.tap(find.byTooltip('السابق').first);
    await tester.pump();
    await tester.scrollUntilVisible(find.text('عرض الشهر'), 300, scrollable: scrollable());
    await tester.tap(find.text('عرض الشهر'));
    await tester.pumpAndSettle();
    expect(find.byType(PrayerMonthScreen), findsOneWidget);
    expect(find.text('١٠'), findsWidgets);
    await tester.tap(find.byTooltip('التالي'));
    await tester.pump();
    await tester.tap(find.byTooltip('السابق'));
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('التقويم الهجري'), 300, scrollable: scrollable());
    await tester.tap(find.text('التقويم الهجري'));
    await tester.pumpAndSettle();
    expect(find.byType(HijriCalendarScreen), findsOneWidget);
  });

  testWidgets('hijri calendar pages through months and lists occasions', (tester) async {
    await pumpScreen(tester, const HijriCalendarScreen(), env);
    expect(find.text('الأيام البيض'), findsOneWidget);
    var found = false;
    for (var i = 0; i < 12 && !found; i++) {
      await tester.tap(find.byTooltip('التالي'));
      await tester.pump();
      found = find.text('عيد الأضحى').evaluate().isNotEmpty;
    }
    expect(found, isTrue);
    for (var i = 0; i < 14; i++) {
      await tester.tap(find.byTooltip('السابق'));
      await tester.pump();
    }
    expect(find.byType(HijriCalendarScreen), findsOneWidget);
  });

  testWidgets('favourites merge verses, hadiths and adhkar with filters', (tester) async {
    await pumpScreen(tester, const FavoritesScreen(), env);
    expect(find.text('لا شيء في المفضلة بعد'), findsOneWidget);
    final c = containerOf(tester, FavoritesScreen);
    c.read(bookmarksProvider.notifier).toggle(const AyahRef(1, 1));
    c.read(favoritesProvider.notifier).toggle('hadith', 'nawawi:1', 'إنما الأعمال بالنيات', 'الأربعون النووية · ١');
    c.read(favoritesProvider.notifier).toggle('zikr', 'x#0', 'سبحان الله', 'أذكار');
    await tester.pump();
    expect(find.byType(AppBar), findsOneWidget);
    expect(find.text('إنما الأعمال بالنيات'), findsOneWidget);
    expect(find.text('سبحان الله'), findsOneWidget);
    await tester.tap(find.text('أحاديث'));
    await tester.pump();
    expect(find.text('سبحان الله'), findsNothing);
    await tester.tap(find.text('إنما الأعمال بالنيات'));
    await tester.pump();
    expect(find.text('تم النسخ'), findsOneWidget);
    await tester.tap(find.byTooltip('إزالة'));
    await tester.pump();
    expect(c.read(favoritesProvider).length, 1);
    await tester.tap(find.text('آيات'));
    await tester.pump();
    await tester.tap(find.byTooltip('إزالة'));
    await tester.pump();
    expect(c.read(bookmarksProvider), isEmpty);
  });

  testWidgets('sadaqa: dedicate a deed then delete it', (tester) async {
    await pumpScreen(tester, const SadaqaScreen(), env);
    expect(find.text('لم تُهدِ عملًا بعد'), findsOneWidget);
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'والدي');
    await tester.tap(find.text('سورة'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'يس');
    await tester.tap(find.widgetWithText(FilledButton, 'حفظ'));
    await tester.pumpAndSettle();
    expect(find.text('والدي'), findsOneWidget);
    expect(find.text('سورة · يس'), findsOneWidget);
    await tester.tap(find.byTooltip('حذف'));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('والدي'), findsNothing);
  });

  testWidgets('sira: sections, events and the verse journey', (tester) async {
    await pumpScreen(tester, const SiraScreen(), env);
    expect(find.text('غزوات الرسول ﷺ'), findsOneWidget);
    await tester.tap(find.text('غزوات الرسول ﷺ'));
    await tester.pumpAndSettle();
    expect(find.byType(SiraSectionScreen), findsOneWidget);
    await tester.tap(find.text('غزوة بدر'));
    await tester.pumpAndSettle();
    expect(find.byType(VerseJourneyScreen), findsOneWidget);
  });

  testWidgets('videos list curated topics', (tester) async {
    await pumpScreen(tester, const VideosScreen(), env);
    expect(find.text('تلاوات خاشعة'), findsOneWidget);
    expect(videoTopics.length, 8);
  });

  testWidgets('radio lists, filters and plays a station', (tester) async {
    await pumpScreen(
      tester,
      ProviderScope(
        overrides: [
          radioStationsProvider.overrideWith((ref) async => const [
                RadioStation('إذاعة القرآن الكريم', 'https://example.com/a'),
                RadioStation('إذاعة تفسير', 'https://example.com/b'),
              ]),
        ],
        child: const RadioScreen(),
      ),
      env,
    );
    await tester.pump();
    expect(find.text('إذاعة تفسير'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'تفسير');
    await tester.pump();
    expect(find.text('إذاعة القرآن الكريم'), findsNothing);
    await tester.tap(find.text('إذاعة تفسير'));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    final c = containerOf(tester, RadioScreen);
    expect(c.read(audioProvider).stream, 'إذاعة تفسير');
    expect(c.read(audioProvider).active, isTrue);
    await tester.tap(find.text('إذاعة تفسير'));
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('audio tafsir lists and filters surahs', (tester) async {
    await pumpScreen(tester, const AudioTafsirScreen(), env);
    await tester.pump();
    expect(find.text('الفاتحة'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'الكهف');
    await tester.pump();
    expect(find.text('الفاتحة'), findsNothing);
    expect(find.text('الكهف'), findsNWidgets(2));
  });

  testWidgets('hadith collections, list search and detail', (tester) async {
    final repo = HadithRepository(bundle: FileBundle(), docsDir: () async => tmp);
    await tester.runAsync(() async {
      await repo.collection('nawawi');
    });
    await pumpScreen(tester, ProviderScope(overrides: [hadithRepoProvider.overrideWithValue(repo)], child: const HadithScreen()), env);
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('الأربعون النووية'), findsOneWidget);
    expect(find.text('صحيح البخاري'), findsOneWidget);
    expect(find.text('حديث اليوم'), findsOneWidget);
    await tester.tap(find.text('الأربعون النووية'));
    await tester.pumpAndSettle();
    expect(find.byType(HadithListScreen), findsOneWidget);
    expect(find.byType(HadithCard), findsWidgets);
    await tester.enterText(find.byType(TextField), 'بالنيات');
    await tester.pump();
    expect(find.byType(HadithCard), findsOneWidget);
    await tester.tap(find.byTooltip('حفظ'));
    await tester.pump();
    expect(containerOf(tester, HadithListScreen).read(favoritesProvider).single.type, 'hadith');
    await tester.tap(find.byTooltip('نسخ'));
    await tester.pump();
    expect(find.text('تم النسخ'), findsOneWidget);
  });
}
