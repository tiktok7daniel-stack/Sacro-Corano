import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mishkah/main.dart' as app;

/// End-to-end smoke test on a real device or emulator:
///   flutter test integration_test
/// CI runs it on an Android emulator (workflow_dispatch, see android.yml).
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('launch → onboarding → read al-Fatiha → search → tasbih', (tester) async {
    app.main();
    // Splash animation + loading the mushaf.
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // First run shows onboarding; skip it.
    final skip = find.text('تخطَّ');
    if (skip.evaluate().isNotEmpty) {
      await tester.tap(skip);
      await tester.pumpAndSettle();
    }
    expect(find.text('السلام عليكم'), findsOneWidget);

    // Quran tab → al-Fatiha.
    await tester.tap(find.text('القرآن').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('الفاتحة').first);
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.textContaining('سُورَةُ الفاتحة'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Search.
    await tester.tap(find.byIcon(Icons.search_rounded).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'الصراط المستقيم');
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.textContaining('نتيجة'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Home → tasbih.
    await tester.tap(find.text('الرئيسية').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('السبحة'), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('السبحة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('٠').first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('١'), findsWidgets);
  });
}
