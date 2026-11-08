import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mishkah/features/prayer/prayer_screen.dart';
import 'package:mishkah/services/notifications.dart';

import '../fakes.dart';
import '../helpers.dart';

void main() {
  setUpAll(loadAppFonts);
  late TestEnv env;
  setUp(() async {
    env = await createEnv();
    silencePlugins();
  });
  tearDown(() async => env.dispose());

  testWidgets('the prayer tab says when the adhan is blocked and fixes it', (tester) async {
    await pumpScreen(
      tester,
      const PrayerScreen(standalone: true),
      env,
      overrides: [
        adhanHealthProvider.overrideWith((ref) async => (const NotificationHealth(enabled: false, exact: false, pendingAdhans: 0), 'boom')),
      ],
    );
    await tester.pump();
    expect(find.text('الأذان لن يعمل بعد'), findsOneWidget);
    expect(find.text('• الإشعارات مقفولة للتطبيق.'), findsOneWidget);
    expect(find.text('• المنبّهات الدقيقة غير مسموحة، فقد يتأخر الأذان.'), findsOneWidget);
    expect(find.text('• تعذّرت جدولة الأذان على هذا الجهاز.'), findsOneWidget);
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    final rec = ChannelRecorder('dexterous.com/flutter/local_notifications', reply: (c) => c.method == 'initialize' ? true : null);
    addTearDown(rec.dispose);
    await tester.tap(find.text('إصلاح الآن'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(rec.named('requestNotificationsPermission'), isNotEmpty);
  });

  testWidgets('when all is well it shows a quiet line with a test button', (tester) async {
    await pumpScreen(
      tester,
      const PrayerScreen(standalone: true),
      env,
      overrides: [
        adhanHealthProvider.overrideWith((ref) async => (const NotificationHealth(enabled: true, exact: true, pendingAdhans: 70), null)),
      ],
    );
    await tester.pump();
    expect(find.text('الأذان مفعّل · ٧٠ تنبيه مجدول'), findsOneWidget);
    expect(find.text('الأذان لن يعمل بعد'), findsNothing);
    final c = ProviderScope.containerOf(tester.element(find.byType(PrayerScreen)));
    expect(c.read(adhanHealthProvider).value!.$1.ok, isTrue);
  });
}
