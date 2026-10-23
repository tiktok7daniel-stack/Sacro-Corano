import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/splash/splash_screen.dart';
import 'providers.dart';

class MishkahApp extends ConsumerWidget {
  const MishkahApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final ThemeMode mode;
    switch (s.theme) {
      case AppThemeKind.system:
        mode = ThemeMode.system;
      case AppThemeKind.night:
        mode = ThemeMode.dark;
      case AppThemeKind.light:
      case AppThemeKind.sepia:
        mode = ThemeMode.light;
    }
    return MaterialApp(
      title: 'Mishkah',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: AppTheme.light(highContrast: s.highContrast, sepia: s.theme == AppThemeKind.sepia),
      darkTheme: AppTheme.night(highContrast: s.highContrast),
      locale: Locale(s.lang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        // Respect the system text scale but keep layouts usable at extremes.
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(minScaleFactor: 0.85, maxScaleFactor: 1.6)),
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}
