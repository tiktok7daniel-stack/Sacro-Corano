import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishkah/app/providers.dart';
import 'package:mishkah/features/ramadan/ramadan_screen.dart';
import 'package:mishkah/features/recitation/recitation_screen.dart';
import 'package:mishkah/features/settings/smart_reminders_screen.dart';
import 'package:mishkah/services/notifications.dart';
import 'package:mishkah/services/speech.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../fakes.dart';
import '../helpers.dart';

/// A recogniser the test drives by hand.
class FakeSpeech implements SpeechEngine {
  FakeSpeech({this.initOk = true, this.arabic = true});
  final bool initOk;
  final bool arabic;
  void Function(String, bool)? onResult;
  bool onDeviceRequested = false;

  @override
  Future<bool> init({required void Function(String error) onError, required void Function() onDone}) async => initOk;
  @override
  Future<bool> hasArabic() async => arabic;
  @override
  Future<void> listen({required void Function(String words, bool isFinal) onResult, bool onDeviceOnly = false}) async {
    this.onResult = onResult;
    onDeviceRequested = onDeviceOnly;
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> cancel() async {}
}

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
    tmp = Directory.systemTemp.createTempSync('mishkah_ram');
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

  testWidgets('recitation check: words turn green and a full verse is celebrated', (tester) async {
    final speech = FakeSpeech();
    await pumpScreen(tester, const RecitationScreen(), env, overrides: [speechEngineProvider.overrideWithValue(speech)]);
    expect(find.text('اختبار التلاوة'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();
    await tester.pump();
    expect(speech.onResult, isNotNull);
    expect(find.text('أسمعك…'), findsOneWidget);

    // Verse 1 of al-Fatiha is the basmala: بسم الله الرحمن الرحيم.
    speech.onResult!('بسم الله', false);
    await tester.pump();
    expect(find.textContaining('من 4 كلمة'), findsNothing);

    speech.onResult!('بسم الله الرحمن الرحيم', true);
    await tester.pump();
    expect(find.text('ما شاء الله! قرأتها كاملة'), findsOneWidget);
  });

  testWidgets('recitation check: a skipped word is reported in the score', (tester) async {
    final speech = FakeSpeech();
    await pumpScreen(tester, const RecitationScreen(), env, overrides: [speechEngineProvider.overrideWithValue(speech)]);
    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();
    await tester.pump();
    speech.onResult!('بسم الله الرحيم', true);
    await tester.pump();
    expect(find.text('ما شاء الله! قرأتها كاملة'), findsNothing);
    expect(find.textContaining('٣ من ٤'), findsOneWidget);
  });

  testWidgets('recitation check: explains when the microphone or Arabic is unavailable', (tester) async {
    await pumpScreen(tester, const RecitationScreen(), env, overrides: [speechEngineProvider.overrideWithValue(FakeSpeech(initOk: false))]);
    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('الميكروفون'), findsWidgets);
  });

  testWidgets('recitation check: hide-text mode covers pending words and on-device is passed on', (tester) async {
    final speech = FakeSpeech();
    await pumpScreen(tester, const RecitationScreen(), env, overrides: [speechEngineProvider.overrideWithValue(speech)]);
    expect(find.text('إخفاء النص'), findsOneWidget);
    await tester.tap(find.text('إخفاء النص'));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pump();
    await tester.tap(find.text('التعرف على الجهاز فقط'));
    await tester.pump();
    await tester.drag(find.byType(ListView), const Offset(0, 400));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();
    await tester.pump();
    expect(speech.onDeviceRequested, isTrue);
  });

  testWidgets('Ramadan mode: countdown, fasting log and qada', (tester) async {
    await pumpScreen(tester, const RamadanScreen(), env);
    expect(find.text('وضع رمضان'), findsOneWidget);
    expect(find.textContaining('من رمضان'), findsOneWidget);
    expect(find.text('الفجر'), findsNothing);

    await tester.tap(find.text('أفطرت'));
    await tester.pump();
    var c = containerOf(tester, RamadanScreen);
    expect(c.read(fastingProvider).totalMissed, 1);
    expect(c.read(fastingProvider).qadaRemaining, 1);

    await tester.scrollUntilVisible(find.text('صمت يومًا قضاءً'), 300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('صمت يومًا قضاءً'));
    await tester.pump();
    await tester.tap(find.text('صمت يومًا قضاءً'));
    await tester.pump();
    c = containerOf(tester, RamadanScreen);
    expect(c.read(fastingProvider).qadaRemaining, 0);

    await tester.scrollUntilVisible(find.text('صمت'), -300, scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('صمت'));
    await tester.pump();
    await tester.tap(find.text('صمت'));
    await tester.pump();
    final ledger = containerOf(tester, RamadanScreen).read(fastingProvider);
    expect(ledger.days.values.where((v) => v == 'f').length, 1);
  });

  testWidgets('Ramadan mode outside the month shows a countdown', (tester) async {
    await pumpScreen(tester, const RamadanScreen(), env, now: DateTime(2026, 6, 1, 14));
    expect(find.textContaining('بعد'), findsWidgets);
    expect(find.text('صيام اليوم'), findsNothing);
  });

  testWidgets('smart reminders: toggles are saved', (tester) async {
    await pumpScreen(tester, const SmartRemindersScreen(), env);
    expect(find.text('تذكيرات ذكية'), findsOneWidget);
    await tester.tap(find.text('سورة الكهف يوم الجمعة'));
    await tester.pump();
    await tester.tap(find.text('صيام الأيام البيض'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1)); // let the reschedule debounce fire
    final s = containerOf(tester, SmartRemindersScreen).read(settingsProvider);
    expect(s.kahfReminder, isTrue);
    expect(s.fastWhiteReminder, isTrue);
    expect(s.fastMonThuReminder, isFalse);
  });
}
