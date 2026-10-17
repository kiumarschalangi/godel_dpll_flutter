/// Design tokens for the UI (see design/godel-dpll-design.html).
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const background = Color(0xFFF3F4F6);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE1E4EA);
  static const control = Color(0xFFD4D8E0); // input / button / pill outlines
  static const inputFill = Color(0xFFF8F9FB);
  static const ink = Color(0xFF14161B);
  static const muted = Color(0xFF545A66);
  static const faint = Color(0xFFA3A8B3); // tree connectors, header dot
  static const accent = Color(0xFF3B3FC4);
  static final accentSoft = accent.withValues(alpha: 0.08);
  static const accentTrack = Color(0xFFDCDEF2);
  static const open = Color(0xFFC2410C); // open branch / countermodel
  static const better = Color(0xFF0F6B4A); // fewer firings than the baseline
  static const barTrack = Color(0xFFECEEF2);
  static const barFill = Color(0xFF6B7180);

  // Verdict panel (dark)
  static const panel = Color(0xFF14161B);
  static const panelCell = Color(0xFF1B1E25);
  static const panelLine = Color(0xFF2A2E37);
  static const panelTrack = Color(0xFF343944);
  static const panelMuted = Color(0xFFA9AFBC);
  static const panelBody = Color(0xFFC3C8D2);
  static const panelMath = Color(0xFFE6E8EE);
  static const valid = Color(0xFF7FE0B5);
  static const validInk = Color(0xFF0B2A1E);
  static const notValid =
      Color(0xFFFDBA74); // light orange, readable on the dark panel
  static const notValidInk = Color(0xFF431407);
}

abstract final class AppRadii {
  static const card = 20.0;
  static const tile = 14.0;
  static const control = 12.0;
}

abstract final class AppText {
  static TextStyle sans(
          {double size = 14,
          FontWeight weight = FontWeight.w400,
          Color color = AppColors.ink}) =>
      GoogleFonts.instrumentSans(
          fontSize: size, fontWeight: weight, color: color);

  static TextStyle math(
          {double size = 16,
          FontWeight weight = FontWeight.w400,
          Color color = AppColors.ink}) =>
      GoogleFonts.stixTwoText(fontSize: size, fontWeight: weight, color: color);

  static TextStyle mono({double size = 14, Color color = AppColors.ink}) =>
      GoogleFonts.jetBrainsMono(fontSize: size, color: color);

  /// "01 · FORMULA"-style section heading.
  static TextStyle sectionLabel({Color color = AppColors.muted}) =>
      sans(size: 13, weight: FontWeight.w600, color: color)
          .copyWith(letterSpacing: 1.04);
}

ThemeData buildAppTheme() {
  final base = ThemeData(useMaterial3: true, colorSchemeSeed: AppColors.accent);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.accent,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      error: AppColors.open,
    ),
    textTheme: GoogleFonts.instrumentSansTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    dividerColor: AppColors.border,
    switchTheme: SwitchThemeData(
      trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      thumbColor: const WidgetStatePropertyAll(Colors.white),
      trackColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.control),
    ),
  );
}

/// White card with the standard border and radius.
class SurfaceCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const SurfaceCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(32)});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
      child: child,
    );
  }
}
