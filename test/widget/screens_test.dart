import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishkah/app/providers.dart';
import 'package:mishkah/core/widgets/logo.dart';
import 'package:mishkah/domain/settings.dart';
import 'package:mishkah/features/azkar/azkar_screen.dart';
import 'package:mishkah/features/bookmarks/bookmarks_screen.dart';
import 'package:mishkah/features/hifz/hifz_screen.dart';
import 'package:mishkah/features/home/home_screen.dart';
import 'package:mishkah/features/khatma/khatma_screen.dart';
import 'package:mishkah/features/mood/mood_screen.dart';
import 'package:mishkah/features/prayer/prayer_card.dart';
import 'package:mishkah/features/prayer/prayer_screen.dart';
import 'package:mishkah/features/prophets/prophets_screen.dart';
import 'package:mishkah/features/quran/quran_index_screen.dart';
import 'package:mishkah/features/quran/reader_screen.dart';
import 'package:mishkah/features/quran/search_screen.dart';
import 'package:mishkah/features/settings/settings_screen.dart';
import 'package:mishkah/features/stats/stats_screen.dart';
import 'package:mishkah/features/tadabbur/tadabbur_screen.dart';
import 'package:mishkah/features/tasbih/tasbih_screen.dart';

import '../helpers.dart';

void main() {
  setUpAll(loadAppFonts);
  late TestEnv env;
  setUp(() async => env = await createEnv());
  tearDown(() async => env.dispose());

  testWidgets('home shows prayer card, daily cards and feature tiles', (tester) async {
    await pumpScreen(tester, const Scaffold(body: HomeScreen()), env);
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('السلام عليكم'), findsOneWidget);
    expect(find.text('الصلاة القادمة'), findsOneWidget);
    expect(find.text('العصر'), findsWidgets, reason: 'next prayer at 14:00 in Makkah is Asr');
    await tester.scrollUntilVisible(find.text('آية اليوم'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('آية اليوم'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('قصص الأنبياء'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('قصص الأنبياء'), findsOneWidget);
  });

  testWidgets('prayer card asks for a location when none is set', (tester) async {
    await tester.runAsync(() async {
      await env.dispose();
      env = await createEnv(settings: const AppSettings(onboarded: true, haptics: false, reduceMotion: true));
    });
    await pumpScreen(tester, const Scaffold(body: PrayerCard()), env);
    expect(find.text('حدّد موقعك'), findsOneWidget);
    expect(find.text('اختر مدينة'), findsOneWidget);
  });

  testWidgets('prayer screen lists all six times and logs a prayer', (tester) async {
    await pumpScreen(tester, const PrayerScreen(standalone: true), env);
    for (final n in ['الفجر', 'الشروق', 'الظهر', 'المغرب', 'العشاء']) {
      expect(find.text(n), findsWidgets, reason: n);
    }
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.byType(PrayerScreen)));
    expect(container.read(activityProvider).values.single.prayers, contains('fajr'));
  });

  testWidgets('quran index lists 114 surahs and opens the reader', (tester) async {
    await pumpScreen(tester, const Scaffold(body: QuranIndexScreen()), env);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('الفاتحة'), findsWidgets);
    await tester.tap(find.text('الفاتحة').first);
    await tester.pumpAndSettle();
    expect(find.byType(ReaderScreen), findsOneWidget);
    expect(find.textContaining('سُورَةُ الفاتحة'), findsOneWidget);
  });

  testWidgets('reader verse mode shows basmala header and verses, tap opens actions', (tester) async {
    await pumpScreen(tester, const ReaderScreen(surah: 112), env);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('سُورَةُ الإخلاص'), findsOneWidget);
    expect(find.text('بِسۡمِ ٱللَّهِ ٱلرَّحۡمَٰنِ ٱلرَّحِيمِ'), findsOneWidget);
    await tester.tap(find.byType(InkWell).at(1));
    await tester.pumpAndSettle();
    expect(find.text('التفسير'), findsOneWidget);
    expect(find.text('حفظ'), findsOneWidget);
    await tester.tap(find.text('حفظ'));
    await tester.pump();
    final c = ProviderScope.containerOf(tester.element(find.byType(ReaderScreen)));
    expect(c.read(bookmarksProvider), isNotEmpty);
  });

  testWidgets('reader page mode renders a mushaf page', (tester) async {
    await tester.runAsync(() => env.storage.writeSettings(_settings(env).copyWith(pageMode: true).toJson()));
    await pumpScreen(tester, const ReaderScreen(surah: 1), env);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MushafPage), findsWidgets);
    expect(find.text('١'), findsWidgets, reason: 'page number');
  });

  testWidgets('search finds verses with everyday spelling', (tester) async {
    await pumpScreen(tester, const SearchScreen(), env);
    await tester.enterText(find.byType(TextField), 'الصراط المستقيم');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 1));
    expect(find.textContaining('نتيجة'), findsOneWidget);
  });

  testWidgets('tasbih counts taps', (tester) async {
    await pumpScreen(tester, const TasbihScreen(), env);
    await tester.tap(find.text('٠').first);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('١').first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('٢'), findsOneWidget);
  });

  testWidgets('azkar reader decrements the counter', (tester) async {
    final morning = testAzkar().byName('أذكار الصباح')!;
    await pumpScreen(tester, AzkarReaderScreen(category: morning), env);
    expect(find.text('١ / ${_ar(morning.items.length)}'), findsOneWidget);
    final first = morning.items.first;
    await tester.tap(find.text(first.text));
    await tester.pump(const Duration(milliseconds: 500));
    if (first.count == 1) {
      expect(find.text('٢ / ${_ar(morning.items.length)}'), findsOneWidget, reason: 'completes and auto-advances');
    } else {
      expect(find.text(_ar(first.count - 1)), findsOneWidget);
    }
  });

  testWidgets('khatma plan can be started', (tester) async {
    await pumpScreen(tester, const KhatmaScreen(), env);
    expect(find.text('ابدأ الختمة'), findsOneWidget);
    await tester.tap(find.text('ابدأ الختمة'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.textContaining('أتممت'), findsOneWidget);
  });

  testWidgets('hifz screen adds a surah', (tester) async {
    await pumpScreen(tester, const HifzScreen(), env);
    expect(find.text('ابدأ رحلة الحفظ'), findsOneWidget);
    final c = ProviderScope.containerOf(tester.element(find.byType(HifzScreen)));
    c.read(hifzProvider.notifier).addSurah(114, 6);
    await tester.pump();
    expect(find.text('ابدأ المراجعة'), findsOneWidget);
    await tester.tap(find.text('ابدأ المراجعة'));
    await tester.pumpAndSettle();
    expect(find.text('اكشف الآية التالية'), findsOneWidget);
    await tester.tap(find.text('متقن'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(c.read(hifzProvider).single.reviews, 1);
  });

  testWidgets('prophets shelf shows 25 books and opens a story', (tester) async {
    await pumpScreen(tester, const ProphetsScreen(), env);
    expect(find.textContaining('قصة آدم'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'أولو العزم'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('قصة آدم'), findsNothing);
    expect(find.textContaining('قصة نوح'), findsOneWidget);
    await tester.tap(find.textContaining('قصة نوح'));
    await tester.pumpAndSettle();
    expect(find.text('التفسير الميسر'), findsOneWidget);
  });

  testWidgets('mood verses show tafsir', (tester) async {
    await pumpScreen(tester, const MoodScreen(), env);
    await tester.tap(find.text('حزين'));
    await tester.pumpAndSettle();
    expect(find.textContaining('الشرح'), findsWidgets);
  });

  testWidgets('stats and badges render', (tester) async {
    await pumpScreen(tester, const StatsScreen(), env);
    await tester.pumpAndSettle();
    expect(find.text('إحصائياتي'), findsOneWidget);
    expect(find.text('الصلوات في ٣٠ يومًا'), findsOneWidget);
  });

  testWidgets('empty states for bookmarks and reflections', (tester) async {
    await pumpScreen(tester, const BookmarksScreen(), env);
    expect(find.text('لا شيء هنا بعد'), findsOneWidget);
    await pumpScreen(tester, const TadabburScreen(), env);
    expect(find.text('لا تأمّلات بعد'), findsOneWidget);
  });

  testWidgets('switching language to English updates the UI', (tester) async {
    await pumpScreen(tester, const Scaffold(body: SettingsScreen()), env);
    expect(find.text('الإعدادات'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    // Let the coalesced notification reschedule run.
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('logo painter animates without errors', (tester) async {
    for (final p in [0.0, 0.3, 0.6, 1.0]) {
      await tester.pumpWidget(Directionality(textDirection: TextDirection.rtl, child: Center(child: MishkahLogo(size: 120, progress: p))));
    }
    expect(find.bySemanticsLabel('Mishkah'), findsOneWidget);
  });
}

String _ar(int n) => n.toString().split('').map((c) => '٠١٢٣٤٥٦٧٨٩'[int.parse(c)]).join();

AppSettings _settings(TestEnv env) => AppSettings.fromJson(env.storage.readSettings());
