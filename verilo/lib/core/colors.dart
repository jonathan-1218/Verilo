import 'package:flutter/material.dart';

abstract final class AppColors {
  static const copperDark = Color(0xFF8C5020);
  static const copperMid = Color(0xFFB87040);
  static const copperLight = Color(0xFFD08848);
  static const copperGlow = Color(0xFFD4956A);
  static const bgDeep = Color(0xFF0D0B09);
  static const bgApp = Color(0xFF1E1B18);
  static const bgCard = Color(0xFF252220);
  static const bgCardElevated = Color(0xFF2A2420);
  static const bgPlaceholder = Color(0xFF2E2A26);
  static const navBar = Color(0xFF141210);
  static const textPrimary = Color(0xFFEDE8E3);
  static const textSecondary = Color(0xFF9A8F88);
  static const textMuted = Color(0xFF5C5550);
  // copper-warmed hairline: every card border carries the brand tint
  static const borderSubtle = Color(0x1AD4956A);
  // true warning amber — deliberately yellower than the brand copper so
  // "pending/attention" state never reads as decoration
  static const amber = Color(0xFFD9A441);
  static const amberBg = Color(0x1FD9A441);
  static const red = Color(0xFFD44040);
  static const blue = Color(0xFF4880C8);
  static const copperGradient = LinearGradient(
    colors: [copperDark, copperLight],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  static const splashGradient = LinearGradient(
    colors: [Color(0xFF141210), Color(0xFF1E1A14), Color(0xFF2A2018)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
