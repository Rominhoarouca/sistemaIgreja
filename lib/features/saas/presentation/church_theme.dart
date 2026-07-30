import 'package:flutter/material.dart';

/// Aplica a cor do menu da igreja (tenant) sobre o tema base do design system:
/// pinta o AppBar e a navegação com a cor escolhida, ajustando o contraste do
/// texto/ícones conforme a luminância.
ThemeData applyChurchMenuColor(ThemeData base, Color? menuColor) {
  if (menuColor == null) return base;

  final onMenu =
      menuColor.computeLuminance() > 0.5 ? const Color(0xFF1A1A1A) : Colors.white;

  return base.copyWith(
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: menuColor,
      foregroundColor: onMenu,
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(color: onMenu),
      iconTheme: IconThemeData(color: onMenu),
      actionsIconTheme: IconThemeData(color: onMenu),
    ),
    navigationBarTheme: base.navigationBarTheme.copyWith(
      indicatorColor: menuColor.withValues(alpha: 0.18),
    ),
    navigationRailTheme: base.navigationRailTheme.copyWith(
      selectedIconTheme: IconThemeData(color: menuColor),
      selectedLabelTextStyle: TextStyle(color: menuColor),
    ),
    drawerTheme: base.drawerTheme,
  );
}
