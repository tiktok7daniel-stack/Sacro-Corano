import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'brand.dart';

enum AppThemeKind { system, night, light, sepia }

/// Reading palette used by the mushaf; independent from the app chrome so a
/// user can keep a dark UI and read on paper, or vice versa.
@immutable
class ReadingPalette extends ThemeExtension<ReadingPalette> {
  const ReadingPalette({
    required this.page,
    required this.ink,
    required this.accent,
    required this.marker,
    required this.highlight,
  });

  final Color page;
  final Color ink;
  final Color accent;
  final Color marker;
  final Color highlight;

  static const night = ReadingPalette(
    page: Brand.night,
    ink: Brand.textHigh,
    accent: Brand.tealBright,
    marker: Brand.gold,
    highlight: Color(0x332FA4AF),
  );
  static const light = ReadingPalette(
    page: Brand.paperSurface,
    ink: Brand.lightInk,
    accent: Brand.tealDeep,
    marker: Brand.goldDeep,
    highlight: Color(0x2A1E7F8A),
  );
  static const sepia = ReadingPalette(
    page: Brand.sepia,
    ink: Brand.sepiaInk,
    accent: Color(0xFF6D4C1F),
    marker: Color(0xFF8A5A1C),
    highlight: Color(0x338A5A1C),
  );

  @override
  ReadingPalette copyWith({Color? page, Color? ink, Color? accent, Color? marker, Color? highlight}) =>
      ReadingPalette(
        page: page ?? this.page,
        ink: ink ?? this.ink,
        accent: accent ?? this.accent,
        marker: marker ?? this.marker,
        highlight: highlight ?? this.highlight,
      );

  @override
  ReadingPalette lerp(ReadingPalette? other, double t) {
    if (other == null) return this;
    return ReadingPalette(
      page: Color.lerp(page, other.page, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      marker: Color.lerp(marker, other.marker, t)!,
      highlight: Color.lerp(highlight, other.highlight, t)!,
    );
  }
}

abstract final class AppTheme {
  static ThemeData night({bool highContrast = false}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Brand.teal,
      brightness: Brightness.dark,
    ).copyWith(
      primary: Brand.tealBright,
      onPrimary: Colors.white,
      secondary: Brand.gold,
      onSecondary: Brand.ink,
      surface: Brand.surface,
      onSurface: highContrast ? Colors.white : Brand.textHigh,
      onSurfaceVariant: highContrast ? const Color(0xFFDDE3E8) : Brand.textMid,
      outline: Brand.outline,
      surfaceContainerHighest: Brand.surfaceHigh,
    );
    return _base(scheme, Brand.ink, ReadingPalette.night);
  }

  static ThemeData light({bool highContrast = false, bool sepia = false}) {
    final scheme = ColorScheme.fromSeed(
      seedColor: Brand.teal,
      brightness: Brightness.light,
    ).copyWith(
      primary: Brand.tealDeep,
      secondary: Brand.goldDeep,
      surface: sepia ? const Color(0xFFF8EEDA) : Colors.white,
      onSurface: highContrast ? Colors.black : Brand.lightInk,
      onSurfaceVariant: highContrast ? const Color(0xFF222222) : const Color(0xFF55606B),
      outline: const Color(0xFFD9D2C3),
    );
    return _base(scheme, sepia ? Brand.sepia : Brand.paper,
        sepia ? ReadingPalette.sepia : ReadingPalette.light);
  }

  static ThemeData _base(ColorScheme scheme, Color background, ReadingPalette reading) {
    final dark = scheme.brightness == Brightness.dark;
    final textTheme = Typography.material2021(platform: TargetPlatform.android)
        .black
        .apply(
          fontFamily: Brand.uiFont,
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      fontFamily: Brand.uiFont,
      textTheme: textTheme,
      extensions: [reading],
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: scheme.onSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        systemOverlayStyle: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? Brand.night : Colors.white,
        indicatorColor: Brand.gold.withValues(alpha: dark ? 0.22 : 0.3),
        height: 72,
        labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
              fontFamily: Brand.uiFont,
              fontSize: 12,
              fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w400,
              color: s.contains(WidgetState.selected) ? Brand.gold : scheme.onSurfaceVariant,
            )),
        iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
              color: s.contains(WidgetState.selected) ? Brand.gold : scheme.onSurfaceVariant,
            )),
      ),
      chipTheme: ChipThemeData(
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outline),
        selectedColor: scheme.primary.withValues(alpha: 0.9),
        labelStyle: TextStyle(fontFamily: Brand.uiFont, color: scheme.onSurface),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(22),
          borderSide: BorderSide(color: scheme.outline),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

extension ReadingPaletteX on BuildContext {
  ReadingPalette get reading => Theme.of(this).extension<ReadingPalette>() ?? ReadingPalette.night;
}
