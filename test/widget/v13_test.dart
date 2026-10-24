import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:mishkah/app/providers.dart';
import 'package:mishkah/data/quran/word_data.dart';
import 'package:mishkah/domain/quran_models.dart';
import 'package:mishkah/features/hifz/recitation_test_screen.dart';
import 'package:mishkah/features/prayer/prayer_screen.dart';
import 'package:mishkah/features/quran/reader_screen.dart';
import 'package:mishkah/features/quran/word_sheet.dart';
import 'package:mishkah/features/ramadan/ramadan_screen.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text_platform_interface/speech_to_text_platform_interface.dart';

import '../fake_audio.dart';
import '../fakes.dart';
import '../helpers.dart';

class FakeSpeech extends SpeechToTextPlatform with MockPlatformInterfaceMixin {
  bool available = true;
  int listens = 0;

  @override
  Future<bool> hasPermission() async => available;
  @override
  Future<bool> initialize({debugLogging = false, List<SpeechConfigOption>? options}) async => available;
  @override
  Future<bool> listen({String? localeId, partialResults = true, onDevice = false, int listenMode = 0, sampleRate = 0, SpeechListenOptions? options}) async {
    listens++;
    onStatus?.call('listening');
    return true;
  }

  @override
  Future<void> stop() async => onStatus?.call('notListening');
  @override
  Future<void> cancel() async {}
  @override
  Future<List<dynamic>> locales() async => ['en_US:English', 'ar_SA:العربية'];

  void say(String words, {bool last = false}) => onTextRecognition?.call(jsonEncode({
        'alternates': [
          {'recognizedWords': words, 'confidence': 0.9},
        ],
        'resultType': last ? 2 : 0,
      }));
}

void main() {
  setUpAll(loadAppFonts);
  late TestEnv env;
  late Directory tmp;
  late FakeSpeech speech;

  setUp(() async {
    env = await createEnv();
    tmp = Directory.systemTemp.createTempSync('mishkah_v13w');
    PathProviderPlatform.instance = FakePathProvider(tmp);
    JustAudioPlatform.instance = FakeJustAudio();
    SpeechToTextPlatform.instance = speech = FakeSpeech();
    silencePlugins();
  });
  tearDown(() async {
    await env.dispose();
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  final speechOverride = speechProvider.overrideWith((ref) => SpeechToText.withMethodChannel());

  testWidgets('recitation test reveals words as they are recited and scores', (tester) async {
    await pumpScreen(tester, const RecitationTestScreen(surah: 112, from: 1, to: 2), env, overrides: [speechOverride]);
    await settle(tester);
    expect(find.text('٠ / ٦'), findsOneWidget);
    expect(find.text('قُلۡ'), findsNothing, reason: 'text hidden until recited');
    await tester.tap(find.byIcon(Icons.mic_rounded));
    await settle(tester);
    expect(speech.listens, 1);
    expect(find.text('يستمع إليك…'), findsOneWidget);
    speech.say('قل هو الله');
    await tester.pump();
    expect(find.text('٣ / ٦'), findsOneWidget);
    expect(find.text('قُلۡ'), findsOneWidget);
    // The recogniser ends after a pause: the session restarts by itself.
    speech.say('قل هو الله', last: true);
    speech.onStatus?.call('done');
    await tester.pump(const Duration(milliseconds: 400));
    await settle(tester);
    expect(speech.listens, greaterThanOrEqualTo(2));
    speech.say('الله الصمد', last: true);
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
    expect(find.textContaining('النتيجة'), findsWidgets);
    expect(find.textContaining('أخطاء أو تجاوز: ١'), findsOneWidget, reason: 'أحد was skipped');
    // Leave the screen and let the recogniser's own timers run out.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 6));
  });

  testWidgets('recitation test hints, shows text and restarts', (tester) async {
    await pumpScreen(tester, const RecitationTestScreen(surah: 112, from: 1, to: 1), env, overrides: [speechOverride]);
    await settle(tester);
    await tester.tap(find.text('الكلمة التالية'));
    await tester.pump();
    expect(find.text('١ / ٤'), findsOneWidget);
    await tester.tap(find.byTooltip('إظهار النص'));
    await tester.pump();
    expect(find.text('أَحَدٌ'), findsOneWidget);
    await tester.tap(find.byTooltip('من جديد'));
    await tester.pump();
    expect(find.text('٠ / ٤'), findsOneWidget);
  });

  testWidgets('recitation test explains when speech is unavailable', (tester) async {
    speech.available = false;
    await pumpScreen(tester, const RecitationTestScreen(surah: 1, from: 1, to: 1), env, overrides: [speechOverride]);
    await settle(tester);
    expect(find.textContaining('تمييز الصوت غير متاح'), findsOneWidget);
  });

  testWidgets('recitation picker searches and picks a range', (tester) async {
    await pumpScreen(tester, const RecitationPickerScreen(), env, overrides: [speechOverride]);
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'الإخلاص');
    await tester.pump();
    await tester.tap(find.text('الإخلاص').last);
    await tester.pumpAndSettle();
    expect(find.text('اختر الآيات'), findsOneWidget);
    await tester.tap(find.text('ابدأ'));
    await tester.pumpAndSettle();
    expect(find.byType(RecitationTestScreen), findsOneWidget);
    await settle(tester);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 6));
  });

  testWidgets('ramadan card and screen: countdown, log and qada', (tester) async {
    // 1 March 2026 is in Ramadan 1447.
    await pumpScreen(tester, const RamadanScreen(), env);
    await tester.pump();
    expect(find.textContaining('من رمضان'), findsOneWidget);
    expect(find.text('الإفطار بعد'), findsOneWidget);
    await tester.tap(find.text('صمتُ اليوم'));
    await tester.pump();
    final c = ProviderScope.containerOf(tester.element(find.byType(RamadanScreen)));
    expect(c.read(fastingProvider).fastedCount, 1);
    await tester.scrollUntilVisible(find.text('صيام القضاء'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('١').first);
    await tester.pump();
    await tester.scrollUntilVisible(find.byTooltip('أكثر'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byTooltip('أكثر'));
    await tester.pump();
    expect(c.read(fastingProvider).extraOwed, 1);
    await tester.tap(find.text('صمتُ يوم قضاء'));
    await tester.pump();
    expect(c.read(fastingProvider).qadaDone, 1);
    await tester.scrollUntilVisible(find.text('ختمة رمضان'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('ختمة رمضان'));
    await tester.pumpAndSettle();
    expect(c.read(khatmaProvider), isNotNull);
  });

  testWidgets('ramadan screen outside Ramadan counts down', (tester) async {
    await pumpScreen(tester, const RamadanScreen(), env, now: DateTime(2026, 10, 24, 12));
    await tester.pump();
    expect(find.textContaining('رمضان بعد'), findsOneWidget);
  });

  testWidgets('reader colours tajweed and a long press opens word meanings', (tester) async {
    final tajweed = TajweedData.parse(File('assets/data/tajweed.json.gz').readAsBytesSync());
    final wbw = WordByWord.parse(File('assets/data/wbw_en.json.gz').readAsBytesSync());
    await pumpScreen(
      tester,
      const ReaderScreen(surah: 112),
      env,
      overrides: [
        tajweedProvider.overrideWith((ref) async => tajweed),
        wordByWordProvider.overrideWith((ref) async => wbw),
      ],
    );
    await settle(tester);
    final rich = tester.widgetList<RichText>(find.byType(RichText));
    var coloured = false;
    for (final r in rich) {
      r.text.visitChildren((s) {
        if (s is TextSpan && s.style?.color != null && (s.text ?? '').isNotEmpty) coloured = true;
        return true;
      });
    }
    expect(coloured, isTrue);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('word sheet shows the word, its meaning and the verse words', (tester) async {
    final wbw = WordByWord.parse(File('assets/data/wbw_en.json.gz').readAsBytesSync());
    await pumpScreen(
      tester,
      Scaffold(body: Builder(builder: (context) => TextButton(onPressed: () => showWordSheet(context, const AyahRef(1, 1), word: 2), child: const Text('open')))),
      env,
      overrides: [wordByWordProvider.overrideWith((ref) async => wbw)],
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('the Most Gracious'), findsOneWidget);
    await tester.tap(find.byType(ChoiceChip).last);
    await tester.pump();
    expect(find.text('the Most Merciful'), findsOneWidget);
    await settle(tester);
  });

  testWidgets('prayer settings: adhan sound, iqama and smart reminders', (tester) async {
    final notifications = ChannelRecorder('dexterous.com/flutter/local_notifications', reply: (c) => c.method == 'initialize' ? true : null);
    addTearDown(notifications.dispose);
    await pumpScreen(tester, const PrayerSettingsScreen(), env);
    final c = ProviderScope.containerOf(tester.element(find.byType(PrayerSettingsScreen)));
    await tester.scrollUntilVisible(find.text('أذان قصير'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('أذان قصير'));
    await tester.pump();
    expect(c.read(settingsProvider).adhanSound, 'short');
    await tester.scrollUntilVisible(find.text('تنبيه الإقامة'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('تنبيه الإقامة'));
    await tester.pump();
    expect(c.read(settingsProvider).iqamaAlert, isTrue);
    await tester.scrollUntilVisible(find.text('صيام الاثنين والخميس (ليلة قبلها)'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('صيام الاثنين والخميس (ليلة قبلها)'));
    await tester.pump();
    expect(c.read(settingsProvider).monThuReminder, isTrue);
    await tester.pump(const Duration(seconds: 1));
  });
}
