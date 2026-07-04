import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design System — Typography
/// Sora — títulos, números de KPI, botões primários (pesos 400–700).
/// Instrument Sans — corpo, labels, inputs (pesos 400–600).
/// Fonte: design_handoff_sistema_igreja/README.md
abstract final class AppTypography {
  // ── Display (heros — ex.: headline do login 40px) ──────────────────────────
  static TextStyle get displayLarge => GoogleFonts.sora(
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.15,
  );

  static TextStyle get displayMedium => GoogleFonts.sora(
    fontSize: 34,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.18,
  );

  static TextStyle get displaySmall => GoogleFonts.sora(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.2,
  );

  // ── Headline (títulos de tela / KPI 26–30px) ───────────────────────────────
  static TextStyle get headlineLarge => GoogleFonts.sora(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.22,
  );

  static TextStyle get headlineMedium => GoogleFonts.sora(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.4,
    height: 1.25,
  );

  static TextStyle get headlineSmall => GoogleFonts.sora(
    fontSize: 26,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
    height: 1.28,
  );

  // ── Title (títulos de card/modal 17–19px) ──────────────────────────────────
  static TextStyle get titleLarge => GoogleFonts.sora(
    fontSize: 19,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static TextStyle get titleMedium => GoogleFonts.sora(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.1,
    height: 1.35,
  );

  static TextStyle get titleSmall => GoogleFonts.sora(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
  );

  // ── Body (corpo 14–15px) ───────────────────────────────────────────────────
  static TextStyle get bodyLarge => GoogleFonts.instrumentSans(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.5,
  );

  static TextStyle get bodyMedium => GoogleFonts.instrumentSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.45,
  );

  static TextStyle get bodySmall => GoogleFonts.instrumentSans(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.1,
    height: 1.4,
  );

  // ── Label (labels/metadata 12.5–13.5px) ────────────────────────────────────
  static TextStyle get labelLarge => GoogleFonts.instrumentSans(
    fontSize: 13.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.4,
  );

  static TextStyle get labelMedium => GoogleFonts.instrumentSans(
    fontSize: 12.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.2,
    height: 1.35,
  );

  static TextStyle get labelSmall => GoogleFonts.instrumentSans(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.5,
    height: 1.4,
  );

  // ── Helpers ────────────────────────────────────────────────────────────────
  /// Botões primários — Sora.
  static TextStyle get buttonLabel => GoogleFonts.sora(
    fontSize: 14.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.1,
    height: 1.2,
  );

  /// Valor de KPI (Sora 30px, desktop) — mobile usa 26px.
  static TextStyle get kpiValue => GoogleFonts.sora(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    height: 1.15,
  );

  static TextStyle get kpiValueMobile =>
      kpiValue.copyWith(fontSize: 26, letterSpacing: -0.4);

  /// Labels de seção uppercase (11–12px, letter-spacing 1–1.2px).
  static TextStyle get sectionLabel => GoogleFonts.instrumentSans(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.1,
    height: 1.4,
  );

  static TextStyle get caption =>
      bodySmall.copyWith(color: const Color(0xFF667085));

  static TextStyle get overline => sectionLabel;
}
