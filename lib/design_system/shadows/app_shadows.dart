import 'package:flutter/material.dart';

/// Design System — Elevation Shadows
abstract final class AppShadows {
  static const List<BoxShadow> none = [];

  static const List<BoxShadow> xs = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 4, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x08000000), blurRadius: 3, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 3)),
  ];

  static const List<BoxShadow> xl = [
    BoxShadow(color: Color(0x1A000000), blurRadius: 24, offset: Offset(0, 12)),
    BoxShadow(color: Color(0x0F000000), blurRadius: 8, offset: Offset(0, 4)),
  ];

  // Sombra com cor da marca (para cards de destaque)
  static List<BoxShadow> branded({double opacity = 0.2}) => [
    BoxShadow(
      color: const Color(0xFF1A56DB).withValues(alpha: opacity),
      blurRadius: 16,
      offset: const Offset(0, 6),
    ),
  ];
}
