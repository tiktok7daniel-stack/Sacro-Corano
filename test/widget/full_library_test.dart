import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:mishkah/domain/mp3quran.dart';
import 'package:mishkah/features/reciters/full_library_screen.dart';
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
    tmp = Directory.systemTemp.createTempSync('mishkah_full');
    PathProviderPlatform.instance = FakePathProvider(tmp);
    JustAudioPlatform.instance = FakeJustAudio();
    silencePlugins();
  });
  tearDown(() async {
    await env.dispose();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  testWidgets('full library: search reciters and list only the surahs a set has', (tester) async {
    final reciters = [
      const FullReciter(
        id: 1,
        name: 'عبد الباسط عبد الصمد',
        moshafs: [
          Moshaf(id: 10, name: 'مرتل', server: 'https://s.example/basit/', surahs: {1, 2}),
          Moshaf(id: 11, name: 'مجود', server: 'https://s.example/basit-m/', surahs: {112}),
        ],
      ),
      const FullReciter(
        id: 2,
        name: 'محمود خليل الحصري',
        moshafs: [
          Moshaf(id: 20, name: 'مرتل', server: 'https://s.example/husr/', surahs: {1}),
        ],
      ),
    ];
    await pumpScreen(tester, const FullLibraryScreen(), env, overrides: [fullRecitersProvider.overrideWith((ref) async => reciters)]);
    await tester.pump();
    expect(find.text('عبد الباسط عبد الصمد'), findsOneWidget);
    expect(find.text('محمود خليل الحصري'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'الحصري');
    await tester.pump();
    expect(find.text('عبد الباسط عبد الصمد'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    await tester.tap(find.text('عبد الباسط عبد الصمد'));
    await tester.pumpAndSettle();
    expect(find.text('الفاتحة'), findsOneWidget);
    expect(find.text('البقرة'), findsOneWidget);
    expect(find.text('الإخلاص'), findsNothing);
    await tester.tap(find.text('مجود'));
    await tester.pumpAndSettle();
    expect(find.text('الإخلاص'), findsOneWidget);
    expect(find.text('الفاتحة'), findsNothing);
  });
}
