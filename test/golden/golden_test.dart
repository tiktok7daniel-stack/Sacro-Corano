@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishkah/app/providers.dart';
import 'package:mishkah/core/theme/app_theme.dart';
import 'package:mishkah/data/quran/mushaf_layout.dart';
import 'package:mishkah/core/theme/brand.dart';
import 'package:mishkah/core/widgets/common.dart';
import 'package:mishkah/core/widgets/logo.dart';
import 'package:mishkah/features/prayer/prayer_card.dart';
import 'package:mishkah/features/quran/reader_screen.dart';
import 'package:mishkah/features/share/share_card.dart';

import '../helpers.dart';

/// Golden images (Linux renderer). Regenerate with:
///   flutter test --update-goldens test/golden
void main() {
  setUpAll(loadAppFonts);
  late TestEnv env;
  setUp(() async => env = await createEnv());
  tearDown(() async => env.dispose());

  Widget frame(Widget child, {double w = 400, double h = 400}) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.night(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(body: Center(child: SizedBox(width: w, height: h, child: child))),
        ),
      );

  testWidgets('logo', (tester) async {
    await tester.pumpWidget(frame(const Center(child: MishkahLogo(size: 320))));
    await expectLater(find.byType(MishkahLogo), matchesGoldenFile('goldens/logo.png'));
  });

  testWidgets('logo animation frames', (tester) async {
    await tester.pumpWidget(frame(const Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
      MishkahLogo(size: 90, progress: 0.25, background: false),
      MishkahLogo(size: 90, progress: 0.55, background: false),
      MishkahLogo(size: 90, progress: 0.8, background: false),
      MishkahLogo(size: 90, progress: 1, background: false),
    ]), h: 120));
    await expectLater(find.byType(Row).first, matchesGoldenFile('goldens/logo_frames.png'));
  });

  testWidgets('verse share card', (tester) async {
    final q = testQuran();
    await tester.pumpWidget(frame(
      Align(alignment: Alignment.topCenter, child: BrandedCard(
        title: 'سورة الفاتحة · 1:1-7',
        child: Text(
          [for (var a = 1; a <= 7; a++) '${q.text(1, a)} ${ayahMarker(a)}'].join(' '),
          textAlign: TextAlign.center,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontFamily: Brand.quranFont, fontSize: 20, height: 2, color: Brand.textHigh),
        ),
      )),
      h: 520,
    ));
    await expectLater(find.byType(BrandedCard), matchesGoldenFile('goldens/verse_card.png'));
  });

  testWidgets('home feature tiles', (tester) async {
    await tester.pumpWidget(frame(
      GridView.count(crossAxisCount: 3, mainAxisSpacing: 14, crossAxisSpacing: 14, childAspectRatio: 0.84, padding: const EdgeInsets.all(14), children: [
        GradientTile(label: 'مواقيت الصلاة', icon: Icons.schedule_rounded, colors: Brand.gPrayer, onTap: () {}),
        GradientTile(label: 'الأذكار', icon: Icons.volunteer_activism_rounded, colors: Brand.gAzkar, onTap: () {}),
        GradientTile(label: 'أدعية قرآنية', icon: Icons.favorite_rounded, colors: Brand.gDua, onTap: () {}),
        GradientTile(label: 'قصص الأنبياء', icon: Icons.auto_stories_rounded, colors: Brand.gProphets, onTap: () {}),
        GradientTile(label: 'الحفظ والمراجعة', icon: Icons.psychology_rounded, colors: Brand.gHifz, onTap: () {}),
        GradientTile(label: 'خطة الختمة', icon: Icons.flag_rounded, colors: Brand.gKhatma, onTap: () {}),
      ]),
      h: 340,
    ));
    await expectLater(find.byType(GridView), matchesGoldenFile('goldens/tiles.png'));
  });

  testWidgets('prayer card', (tester) async {
    await pumpScreen(tester, const Scaffold(body: Align(alignment: Alignment.topCenter, child: Padding(padding: EdgeInsets.all(16), child: PrayerCard()))), env);
    await tester.pump(const Duration(seconds: 1));
    await expectLater(find.byType(PrayerCard), matchesGoldenFile('goldens/prayer_card.png'));
  });

  // A phone-sized mushaf page must fit with no overflow, in both palettes.
  for (final (name, page, theme) in [('mushaf_page_1', 1, AppThemeKind.night), ('mushaf_page_50', 50, AppThemeKind.light), ('mushaf_page_604', 604, AppThemeKind.sepia), ('mushaf_page_2', 2, AppThemeKind.light), ('mushaf_page_255', 255, AppThemeKind.light)]) {
    testWidgets('mushaf page $page', (tester) async {
      await pumpScreen(
        tester,
        Builder(
          builder: (context) => Theme(
            data: Theme.of(context).copyWith(extensions: [switch (theme) {
              AppThemeKind.light => ReadingPalette.light,
              AppThemeKind.sepia => ReadingPalette.sepia,
              _ => ReadingPalette.night,
            }]),
            child: Scaffold(body: MushafPage(quran: testQuran(), page: page, onAyahTap: (_) {})),
          ),
        ),
        env,
        overrides: [mushafLayoutProvider.overrideWith((ref) async => MushafLayout.parse(File('assets/data/mushaf_lines.json.gz').readAsBytesSync()))],
      );
      await tester.pump();
      await tester.pump();
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MushafPage), matchesGoldenFile('goldens/$name.png'));
    });
  }
}
