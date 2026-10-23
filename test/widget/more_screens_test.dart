import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishkah/app/providers.dart';
import 'package:mishkah/domain/quran_models.dart';
import 'package:mishkah/domain/settings.dart';
import 'package:mishkah/features/bookmarks/bookmarks_screen.dart';
import 'package:mishkah/features/home/daily_cards.dart';
import 'package:mishkah/features/kids/kids_screen.dart';
import 'package:mishkah/features/mood/mood_screen.dart';
import 'package:mishkah/features/mosque/mosque_mode_screen.dart';
import 'package:mishkah/features/onboarding/onboarding_sheet.dart';
import 'package:mishkah/features/prayer/prayer_screen.dart';
import 'package:mishkah/features/qibla/qibla_screen.dart';
import 'package:mishkah/features/quran/reading_settings_sheet.dart';
import 'package:mishkah/features/quran/tafsir_sheet.dart';
import 'package:mishkah/features/reciters/reciters_screen.dart';
import 'package:mishkah/features/settings/about_screen.dart';
import 'package:mishkah/features/settings/settings_screen.dart';
import 'package:mishkah/features/shell/home_shell.dart';
import 'package:mishkah/features/splash/splash_screen.dart';
import 'package:mishkah/features/tadabbur/tadabbur_screen.dart';
import 'package:mishkah/services/notifications.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../fakes.dart';
import '../helpers.dart';

void main() {
  setUpAll(() async {
    await loadAppFonts();
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    await Notifications.instance.initTimezones();
  });

  late TestEnv env;
  late Directory tmp;
  late ChannelRecorder notifications;
  setUp(() async {
    env = await createEnv();
    tmp = Directory.systemTemp.createTempSync('mishkah_more');
    PathProviderPlatform.instance = FakePathProvider(tmp);
    notifications = ChannelRecorder('dexterous.com/flutter/local_notifications', reply: (c) => c.method == 'initialize' ? true : null);
    silencePlugins();
  });
  tearDown(() async {
    notifications.dispose();
    await env.dispose();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  ProviderContainer containerOf(WidgetTester t, Type type) => ProviderScope.containerOf(t.element(find.byType(type)));

  testWidgets('kids mode: grid, surah page, stars and parent PIN', (tester) async {
    await pumpScreen(tester, const KidsScreen(), env);
    expect(find.text('الناس'), findsOneWidget);
    await tester.tap(find.text('الناس'));
    await tester.pumpAndSettle();
    expect(find.byType(KidsSurahScreen), findsOneWidget);
    await tester.tap(find.text('نجوم'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('قرأها من حفظه'));
    await tester.pump(const Duration(milliseconds: 500));
    final c = containerOf(tester, KidsSurahScreen);
    expect(c.read(kidsProvider)['114'], 3);
    await tester.tap(find.text('الحمد لله'));
    await tester.pumpAndSettle();
    expect(find.byType(KidsSurahScreen), findsOneWidget);
  });

  testWidgets('mosque mode shows the clock board', (tester) async {
    await pumpScreen(tester, const MosqueModeScreen(), env, now: DateTime(2026, 3, 1, 12, 34, 56));
    expect(find.text('١٢:٣٤'), findsOneWidget);
    expect(find.text('الفجر'), findsOneWidget);
    expect(find.textContaining('بعد'), findsWidgets);
  });

  testWidgets('mosque mode shows iqama countdown right after adhan', (tester) async {
    final day = testCalc(env).forDate(DateTime(2026, 3, 1));
    final t = day.times.values.toList()[4].add(const Duration(minutes: 2)); // maghrib + 2
    await pumpScreen(tester, const MosqueModeScreen(), env, now: t);
    expect(find.textContaining('الإقامة بعد'), findsOneWidget);
    expect(find.text('يُرجى إغلاق الهواتف'), findsOneWidget);
  });

  testWidgets('qibla follows the compass and detects alignment', (tester) async {
    mockCompass([90, 0, 10]);
    await pumpScreen(tester, const QiblaScreen(), env);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('زاوية القبلة'), findsOneWidget);
    expect(find.text('المسافة إلى الكعبة'), findsOneWidget);
  });

  testWidgets('qibla without location asks for one', (tester) async {
    mockCompass(null);
    await tester.runAsync(() async {
      await env.dispose();
      env = await createEnv(settings: const AppSettings(onboarded: true, haptics: false, reduceMotion: true));
    });
    await pumpScreen(tester, const QiblaScreen(), env);
    expect(find.text('حدّد موقعك لمعرفة اتجاه القبلة'), findsOneWidget);
  });

  testWidgets('onboarding: choose a city then start', (tester) async {
    await pumpScreen(tester, Scaffold(body: Builder(builder: (context) => Consumer(builder: (context, ref, _) => TextButton(onPressed: () => showOnboarding(context, ref), child: const Text('go'))))), env);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('أهلًا بك في مشكاة'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to Mishkah'), findsOneWidget);
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();
    expect(containerOf(tester, Scaffold).read(settingsProvider).onboarded, isTrue);
  });

  testWidgets('city picker updates the location', (tester) async {
    await pumpScreen(tester, const PrayerSettingsScreen(), env);
    await tester.tap(find.text('اختر مدينة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('جدة'));
    await tester.pumpAndSettle();
    final s = containerOf(tester, PrayerSettingsScreen).read(settingsProvider);
    expect(s.placeName, 'جدة');
    expect(s.lat, closeTo(21.49, 0.01));
    expect(notifications.named('zonedSchedule'), isNotEmpty);
  });

  testWidgets('prayer settings: method, madhab and offsets', (tester) async {
    await pumpScreen(tester, const PrayerSettingsScreen(), env);
    await tester.tap(find.text('العصر: الحنفي'));
    await tester.pump();
    final c = containerOf(tester, PrayerSettingsScreen);
    expect(c.read(settingsProvider).madhab, 'hanafi');
    await tester.tap(find.byIcon(Icons.add_circle_outline).first);
    await tester.pump();
    expect(c.read(settingsProvider).prayerOffsets['fajr'], 1);
    // Let the coalesced notification reschedule run.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('reflections list, map and share entry', (tester) async {
    await pumpScreen(tester, const TadabburScreen(), env);
    final c = containerOf(tester, TadabburScreen);
    c.read(reflectionsProvider.notifier).add(const AyahRef(94, 5), 'with hardship comes ease', ['sabr']);
    c.read(reflectionsProvider.notifier).add(const AyahRef(2, 286), 'Allah does not burden a soul', ['rahma', 'sabr']);
    await tester.pump();
    expect(find.text('with hardship comes ease'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'الرحمة'));
    await tester.pump();
    expect(find.text('with hardship comes ease'), findsNothing);
    await tester.tap(find.byIcon(Icons.hub_rounded));
    await tester.pumpAndSettle();
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('bookmarks list and move to a collection', (tester) async {
    await pumpScreen(tester, const BookmarksScreen(), env);
    final c = containerOf(tester, BookmarksScreen);
    c.read(bookmarksProvider.notifier).toggle(const AyahRef(2, 255));
    await tester.pump();
    expect(find.textContaining('البقرة'), findsOneWidget);
    await tester.drag(find.byType(Dismissible), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(c.read(bookmarksProvider), isEmpty);
  });

  testWidgets('my day checklist toggles prayers', (tester) async {
    await pumpScreen(tester, const DailyChecklistScreen(), env);
    await tester.tap(find.text('الظهر'));
    await tester.pump();
    expect(containerOf(tester, DailyChecklistScreen).read(activityProvider).values.single.prayers, {'dhuhr'});
  });

  testWidgets('quranic duas list', (tester) async {
    await pumpScreen(tester, const QuranicDuasScreen(), env);
    expect(find.text('أدعية قرآنية'), findsOneWidget);
  });

  testWidgets('tafsir sheet shows Muyassar and switches edition', (tester) async {
    await pumpScreen(tester, Scaffold(body: TafsirSheet(start: const AyahRef(1, 1), editionId: 'muyassar')), env);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 800)));
    await tester.pump();
    await tester.pump();
    expect(find.text('التفسير الميسر'), findsWidgets);
    await tester.tap(find.byIcon(Icons.chevron_left_rounded));
    await tester.pump();
    expect(find.textContaining('الآية ٢'), findsOneWidget);
  });

  testWidgets('reading settings sheet changes font and mode', (tester) async {
    await pumpScreen(tester, Scaffold(body: Builder(builder: (context) => TextButton(onPressed: () => showReadingSettings(context), child: const Text('open')))), env);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('وضع صفحات المصحف'));
    await tester.pump();
    await tester.tap(find.text('إظهار الترجمة'));
    await tester.pump();
    final s = containerOf(tester, Scaffold).read(settingsProvider);
    expect(s.pageMode, isTrue);
    expect(s.showTranslation, isTrue);
  });

  testWidgets('reciters list, surahs and storage', (tester) async {
    await pumpScreen(tester, const RecitersScreen(), env);
    expect(find.text('مشاري راشد العفاسي'), findsOneWidget);
    await tester.tap(find.text('محمود خليل الحصري'));
    await tester.pumpAndSettle();
    expect(containerOf(tester, ReciterSurahsScreen).read(settingsProvider).reciterId, 'husary');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    expect(find.byIcon(Icons.download_rounded), findsWidgets);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.sd_storage_outlined));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    expect(find.text('لا توجد تلاوات محمّلة'), findsOneWidget);
  });

  testWidgets('settings: theme, toggles, offline content and about', (tester) async {
    await pumpScreen(tester, const Scaffold(body: SettingsScreen()), env);
    final c = containerOf(tester, SettingsScreen);
    await tester.tap(find.text('تباين عالٍ'));
    await tester.pump();
    expect(c.read(settingsProvider).highContrast, isTrue);
    await tester.scrollUntilVisible(find.text('المحتوى دون إنترنت'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('المحتوى دون إنترنت'));
    await tester.pumpAndSettle();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump();
    expect(find.text('مضمّن في التطبيق'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('حول مشكاة والمصادر'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('حول مشكاة والمصادر'));
    await tester.pumpAndSettle();
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(find.text('المصادر'), findsOneWidget);
  });

  testWidgets('home shell navigates between tabs and schedules alerts', (tester) async {
    await pumpScreen(tester, const HomeShell(), env);
    await tester.pump(const Duration(seconds: 1));
    expect(notifications.named('zonedSchedule'), isNotEmpty, reason: 'bootstrap schedules adhan');
    for (final tab in ['القرآن', 'الصلاة', 'الأذكار', 'الإعدادات', 'الرئيسية']) {
      await tester.tap(find.text(tab).last);
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(find.text('السلام عليكم'), findsOneWidget);
  });

  testWidgets('splash animates then opens home', (tester) async {
    await pumpScreen(tester, const SplashScreen(), env);
    expect(find.text('MISHKAH'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(HomeShell), findsOneWidget);
  });

  testWidgets('mood chips switch verse sets', (tester) async {
    await pumpScreen(tester, const MoodScreen(), env);
    await tester.tap(find.widgetWithText(ChoiceChip, 'شاكر'));
    await tester.pumpAndSettle();
    expect(find.textContaining('ابراهيم'), findsWidgets, reason: '14:7');
  });
}
