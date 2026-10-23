import 'package:flutter/material.dart';

/// Mishkah brand palette. See docs/BRAND.md for usage rules.
abstract final class Brand {
  // Night (default) surfaces
  static const ink = Color(0xFF0A0E15);
  static const night = Color(0xFF0F1520);
  static const surface = Color(0xFF17212B);
  static const surfaceHigh = Color(0xFF1F2B36);
  static const outline = Color(0xFF2A3843);

  // Identity colours
  static const teal = Color(0xFF1E7F8A);
  static const tealBright = Color(0xFF34A9B4);
  static const tealDeep = Color(0xFF0F4C57);
  static const gold = Color(0xFFD6B26E);
  static const goldDeep = Color(0xFFA9833F);

  // Text
  static const textHigh = Color(0xFFEDEAE3);
  static const textMid = Color(0xFFA7B0BA);
  static const textLow = Color(0xFF6E7A86);

  // Paper (light / sepia reading)
  static const paper = Color(0xFFF7F2E7);
  static const paperSurface = Color(0xFFFFFBF2);
  static const sepia = Color(0xFFF1E4C8);
  static const sepiaInk = Color(0xFF3B2F1E);
  static const lightInk = Color(0xFF1B2229);

  // Feature tile gradients (home grid)
  static const gPrayer = [Color(0xFF1E6FD0), Color(0xFF5AAEF0)];
  static const gAzkar = [Color(0xFF5B67C9), Color(0xFF8C97E0)];
  static const gDua = [Color(0xFFE5376F), Color(0xFFF39AB8)];
  static const gReciters = [Color(0xFF0E8A98), Color(0xFF4CCAD8)];
  static const gTasbih = [Color(0xFFA54FC6), Color(0xFFD99BE6)];
  static const gQibla = [Color(0xFF2E9F7C), Color(0xFF6ED1AE)];
  static const gProphets = [Color(0xFF8C6A5E), Color(0xFFC9A698)];
  static const gHifz = [Color(0xFF4F3DB8), Color(0xFF9B7FE6)];
  static const gKhatma = [Color(0xFFB7791F), Color(0xFFE8B45A)];
  static const gKids = [Color(0xFFF07B3F), Color(0xFFFFB37A)];
  static const gMosque = [Color(0xFF155E63), Color(0xFF3A9DA3)];
  static const gStats = [Color(0xFF2F6B4F), Color(0xFF63B38A)];

  static const quranFont = 'AmiriQuran';
  static const naskhFont = 'Amiri';
  static const uiFont = 'ReadexPro';
}
