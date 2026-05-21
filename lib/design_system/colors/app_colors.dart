import 'package:flutter/material.dart';

/// Design System — Color Tokens
/// Paleta inspirada na identidade visual do wireframe (azul institucional + brancos)
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF1A56DB); // Azul principal
  static const Color primaryLight = Color(0xFF3B82F6); // Azul claro
  static const Color primaryDark = Color(0xFF1E40AF); // Azul escuro
  static const Color primarySurface = Color(0xFFEFF6FF); // Fundo azul suave

  // ── Secondary ──────────────────────────────────────────────────────────────
  static const Color secondary = Color(0xFF0EA5E9);
  static const Color secondaryLight = Color(0xFF38BDF8);
  static const Color secondarySurface = Color(0xFFF0F9FF);

  // ── Accent / CTA ───────────────────────────────────────────────────────────
  static const Color accent = Color(0xFF6366F1); // Índigo para destaques

  // ── Neutrals ───────────────────────────────────────────────────────────────
  static const Color grey50 = Color(0xFFF9FAFB);
  static const Color grey100 = Color(0xFFF3F4F6);
  static const Color grey200 = Color(0xFFE5E7EB);
  static const Color grey300 = Color(0xFFD1D5DB);
  static const Color grey400 = Color(0xFF9CA3AF);
  static const Color grey500 = Color(0xFF6B7280);
  static const Color grey600 = Color(0xFF4B5563);
  static const Color grey700 = Color(0xFF374151);
  static const Color grey800 = Color(0xFF1F2937);
  static const Color grey900 = Color(0xFF111827);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // ── Status badges (mapeados dos status do sistema) ─────────────────────────
  static const Color statusNew = Color(0xFF3B82F6); // Novo visitante
  static const Color statusFollowing = Color(0xFFF59E0B); // Em acompanhamento
  static const Color statusIntegrated = Color(0xFF10B981); // Integrado
  static const Color statusInactive = Color(0xFF6B7280); // Não retornou

  // ── Surface & Background ───────────────────────────────────────────────────
  static const Color background = Color(0xFFF9FAFB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF3F4F6);
  static const Color divider = Color(0xFFE5E7EB);

  // ── Dark mode ──────────────────────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surfaceVariantDark = Color(0xFF334155);
  static const Color dividerDark = Color(0xFF334155);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF111827);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Utility
  static const Color transparent = Colors.transparent;
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
}
