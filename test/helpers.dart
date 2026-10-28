import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive_ce.dart';
import 'package:mishkah/app/providers.dart';
import 'package:mishkah/core/theme/app_theme.dart';
import 'package:mishkah/data/azkar_repository.dart';
import 'package:mishkah/data/local/storage.dart';
import 'package:mishkah/data/quran/content_repository.dart';
import 'package:mishkah/data/quran/quran_data.dart';
import 'package:mishkah/domain/prayer_times.dart';
import 'package:mishkah/domain/quran_models.dart';
import 'package:mishkah/domain/search_engine.dart';
import 'package:mishkah/domain/settings.dart';

QuranData? _quran;
SearchEngine? _engine;

/// Built synchronously: compute() never completes inside testWidgets.
SearchEngine testSearchEngine() => _engine ??= () {
      final q = testQuran();
      return SearchEngine(
        refs: [for (final s in q.surahs) for (var a = 1; a <= s.ayahCount; a++) AyahRef(s.number, a)],
        arabicIndex: QuranData.buildSearchIndex(q.rawText),
        isMeccan: (n) => q.surah(n).meccan,
        juzOf: (r) => q.juzOf(r.surah, r.ayah),
      );
    }();
AzkarData? _azkar;

QuranData testQuran() => _quran ??= QuranData.fromRaw(
      File('assets/data/meta.json').readAsStringSync(),
      File('assets/data/quran_uthmani.json.gz').readAsBytesSync(),
    );

AzkarData testAzkar() => _azkar ??= AzkarData.parse(File('assets/data/azkar.json.gz').readAsBytesSync());

/// Serves assets from the repository so compute()/rootBundle are not needed.
class FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(File(key).readAsBytesSync());
}

class TestEnv {
  TestEnv(this.storage, this.dir);
  final Storage storage;
  final Directory dir;

  /// Writes made inside testWidgets' fake-async zone may never resolve, so
  /// closing is best-effort with a deadline.
  Future<void> dispose() async {
    try {
      await Hive.close().timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    } catch (_) {}
  }
}

Future<TestEnv> createEnv({AppSettings? settings}) async {
  final dir = Directory.systemTemp.createTempSync('mishkah_widget');
  final storage = await Storage.initForTest(dir.path);
  await storage.writeSettings((settings ??
          const AppSettings(
            lat: 21.4225,
            lng: 39.8262,
            placeName: 'مكة المكرمة',
            calcMethod: 'umm_al_qura',
            haptics: false,
            reduceMotion: true,
            onboarded: true,
            autoLocation: false,
            pageMode: false,
          ))
      .toJson());
  // Tests pick the reading mode themselves.
  await storage.write('mig_mushafPages', true);
  return TestEnv(storage, dir);
}

/// Pumps [child] inside the app's theme, RTL locale and test providers.
Future<void> pumpScreen(WidgetTester tester, Widget child, TestEnv env, {String lang = 'ar', DateTime? now, List overrides = const []}) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final clock = now ?? DateTime(2026, 3, 1, 14, 0, 0);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      storageProvider.overrideWithValue(env.storage),
      quranProvider.overrideWith((ref) async => testQuran()),
      azkarProvider.overrideWith((ref) async => testAzkar()),
      contentRepoProvider.overrideWithValue(ContentRepository(bundle: FileBundle())),
      clockProvider.overrideWith((ref) => Stream.value(clock)),
      searchEngineProvider.overrideWith((ref) async => testSearchEngine()),
      ...overrides.cast(),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        final s = ref.watch(settingsProvider);
        return MaterialApp(
          theme: AppTheme.night(),
          locale: Locale(s.lang),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: child,
        );
      },
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Loads the real fonts so golden images show Arabic text, not boxes.
Future<void> loadAppFonts() async {
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      loader.addFont(Future.value(ByteData.sublistView(File(f).readAsBytesSync())));
    }
    await loader.load();
  }

  await load('AmiriQuran', ['assets/fonts/AmiriQuran-Regular.ttf']);
  await load('Amiri', ['assets/fonts/Amiri-Regular.ttf', 'assets/fonts/Amiri-Bold.ttf']);
  await load('ReadexPro', ['assets/fonts/ReadexPro-400.ttf', 'assets/fonts/ReadexPro-500.ttf', 'assets/fonts/ReadexPro-700.ttf']);
  // flutter_tester lives in <sdk>/bin/cache/artifacts/engine/<platform>/.
  final exe = Platform.resolvedExecutable;
  final cache = exe.contains('/bin/cache/') ? exe.substring(0, exe.indexOf('/bin/cache/') + '/bin/cache'.length) : null;
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = [
    if (cache != null) '$cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    if (root != null) '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  ].firstWhere((p) => File(p).existsSync(), orElse: () => '');
  if (icons.isNotEmpty) await load('MaterialIcons', [icons]);
}

PrayerCalculator testCalc(TestEnv env) => PrayerCalculator(AppSettings.fromJson(env.storage.readSettings()));
