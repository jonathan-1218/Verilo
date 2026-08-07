import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

abstract final class AppText {
  static TextStyle spaceGrotesk({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textPrimary,
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle jetBrainsMono({
    double size = 11,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.textMuted,
  }) =>
      GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight, color: color);

  // brand lockup order: 'veri' neutral, 'lo' copper (see exports/)
  static TextStyle get logoVeri => spaceGrotesk(
        size: 28, weight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5);
  static TextStyle get logoLo => spaceGrotesk(
        size: 28, weight: FontWeight.w700, color: AppColors.copperGlow, letterSpacing: -0.5);
  // scale: stat 26 > screenTitle 17 < sectionHeading 18 was inverted before —
  // titles now outrank section heads, and stats are the display voice (in an
  // audit app the numbers ARE the content)
  static TextStyle get screenTitle => spaceGrotesk(size: 17, weight: FontWeight.w700, letterSpacing: -0.2);
  static TextStyle get sectionHeading => spaceGrotesk(size: 16, weight: FontWeight.w700);
  static TextStyle get cardTitle => spaceGrotesk(size: 14, weight: FontWeight.w600);
  static TextStyle get body => spaceGrotesk(size: 13, color: AppColors.textSecondary, height: 1.45);
  static TextStyle get label => spaceGrotesk(
        size: 10, weight: FontWeight.w600, color: AppColors.textSecondary,
        letterSpacing: 1.2);
  static TextStyle get stat => spaceGrotesk(size: 26, weight: FontWeight.w700, letterSpacing: -0.5);
}
