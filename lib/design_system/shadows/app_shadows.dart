import 'package:flutter/material.dart';

/// Design System — Elevation Shadows
/// Fonte: design_handoff_sistema_igreja/README.md
abstract final class AppShadows {
  static const List<BoxShadow> none = [];

  /// Sombra de card: `0 1px 2px rgba(16,24,40,.04)`.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x0A101828), blurRadius: 2, offset: Offset(0, 1)),
  ];

  /// Sombra de modal: `0 24px 64px -12px rgba(0,0,0,.4)`.
  static const List<BoxShadow> modal = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 64,
      spreadRadius: -12,
      offset: Offset(0, 24),
    ),
  ];

  /// Halo de foco de input: `0 0 0 3px rgba(30,58,138,.12)`.
  static const List<BoxShadow> focusRing = [
    BoxShadow(color: Color(0x1F1E3A8A), spreadRadius: 3),
  ];

  static const List<BoxShadow> xs = card;

  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0F101828), blurRadius: 4, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A101828), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x0F101828), blurRadius: 8, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x08101828), blurRadius: 3, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x14101828), blurRadius: 16, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A101828), blurRadius: 6, offset: Offset(0, 3)),
  ];

  static const List<BoxShadow> xl = modal;

  // Sombra com cor da marca (para cards de destaque)
  static List<BoxShadow> branded({double opacity = 0.2}) => [
    BoxShadow(
      color: const Color(0xFF1E3A8A).withValues(alpha: opacity),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}
