import 'package:flutter/material.dart';

/// NEURA-inspired dark theme: deep space-purple background with a
/// violet/magenta accent glow. Names are kept stable (AppColors.textDark,
/// AppColors.card, etc.) so existing screens don't need every reference
/// rewritten — only the values changed meaning: "textDark" is now the
/// *primary* text tone for the dark surface (near-white).
class AppColors {
  // Core surface
  static const Color background = Color(0xFF0E0A1A); // near-black purple
  static const Color backgroundDeep = Color(0xFF090614); // darkest, for gradients
  static const Color backgroundGlow = Color(0xFF2A1750); // soft purple glow pockets

  // Cards / surfaces
  static const Color card = Color(0xFF19122C); // solid card fallback
  static const Color cardAlt = Color(0xFF211934);

  // Text
  static const Color textDark = Color(0xFFF3F0FA); // primary (near-white)
  static const Color textMuted = Color(0xFFA79BC9); // secondary lavender-grey

  // Accent (violet -> magenta)
  static const Color accent = Color(0xFF9B6BFF);
  static const Color accentDeep = Color(0xFF6E3BD6);
  static const Color accentSoft = Color(0xFFC9B2FF);
  static const Color magenta = Color(0xFFE85CD0);
  static const Color teal = Color(0xFF3FE0C5);

  // Glass effect tokens
  static const Color glassFill = Color(0x14FFFFFF); // white @ ~8%
  static const Color glassFillStrong = Color(0x22FFFFFF); // white @ ~13%
  static const Color glassBorder = Color(0x33FFFFFF); // white @ ~20%
  static const Color glassShadow = Color(0x66000000);

  static const List<Color> accentGradient = [accent, magenta];
  static const List<Color> backgroundGradient = [backgroundDeep, background, backgroundGlow];

  /// Iridescent ring used on the voice/listening screen.
  static const List<Color> voiceRing = [accent, magenta, teal, accentDeep, accent];
}
