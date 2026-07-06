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

  static TextStyle get logoVeri => spaceGrotesk(
        size: 28, weight: FontWeight.w700, color: AppColors.copperGlow, letterSpacing: -0.5);
  static TextStyle get logoLo => spaceGrotesk(
        size: 28, weight: FontWeight.w700, color: AppColors.textPrimary, letterSpacing: -0.5);
  static TextStyle get screenTitle => spaceGrotesk(size: 15, weight: FontWeight.w700);
  static TextStyle get sectionHeading => spaceGrotesk(size: 18, weight: FontWeight.w700);
  static TextStyle get cardTitle => spaceGrotesk(size: 14, weight: FontWeight.w600);
  static TextStyle get body => spaceGrotesk(size: 13, color: AppColors.textSecondary);
  static TextStyle get label => spaceGrotesk(
        size: 10, weight: FontWeight.w600, color: AppColors.textSecondary,
        letterSpacing: 1.0);
  static TextStyle get stat => spaceGrotesk(size: 22, weight: FontWeight.w700);
}
