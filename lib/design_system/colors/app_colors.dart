import 'package:flutter/material.dart';

/// Design System — Color Tokens
/// Paleta "premium e sóbria" (azul profundo) do redesign 2026.
/// Fonte: design_handoff_sistema_igreja/README.md
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF1E3A8A); // Botões primários, links
  static const Color primaryHover = Color(0xFF16307A); // Hover de botão primário
  static const Color primaryLight = Color(0xFF3E63DD); // Accent (dark mode)
  static const Color primaryDark = Color(0xFF16307A);
  static const Color primarySurface = Color(0xFFEFF4FF); // chip — fundos azuis
  static const Color linkDark = Color(0xFF93B4FD); // primary em dark

  // ── Navy (sidebar / painéis de marca) ──────────────────────────────────────
  static const Color navy900 = Color(0xFF0B1530);
  static const Color navy800 = Color(0xFF122452);
  static const Color navy850 = Color(0xFF101E42);

  // ── Accent gold (sidebar/steppers em fundo escuro) ─────────────────────────
  static const Color gold = Color(0xFFE8A33D);

  // ── Secondary (legado — mapeado para paleta nova) ──────────────────────────
  static const Color secondary = Color(0xFF3E63DD);
  static const Color secondaryLight = Color(0xFF5B8DEF);
  static const Color secondarySurface = Color(0xFFEFF4FF);

  // ── Accent / CTA ───────────────────────────────────────────────────────────
  static const Color accent = Color(0xFF1E3A8A);

  // ── Chips / seleção ────────────────────────────────────────────────────────
  static const Color chip = Color(0xFFEFF4FF); // fundos de chips/ícones azuis
  static const Color chip2 = Color(0xFFF5F8FF); // linha selecionada, hover

  // ── Neutrals (escala mapeada dos tokens de texto/borda do handoff) ─────────
  static const Color grey50 = Color(0xFFF9FAFB); // surface-2
  static const Color grey100 = Color(0xFFF2F4F7);
  static const Color grey200 = Color(0xFFE4E7EC); // border container
  static const Color grey300 = Color(0xFFD0D5DD); // border input
  static const Color grey400 = Color(0xFF98A2B3); // muted
  static const Color grey500 = Color(0xFF667085); // text-3
  static const Color grey600 = Color(0xFF475467); // text-2
  static const Color grey700 = Color(0xFF344054); // labels
  static const Color grey800 = Color(0xFF1D2939);
  static const Color grey900 = Color(0xFF101828); // text

  // ── Bordas ─────────────────────────────────────────────────────────────────
  static const Color border = Color(0xFFE9ECF2); // bordas de card
  static const Color borderContainer = Color(0xFFE4E7EC);
  static const Color borderInput = Color(0xFFD0D5DD);
  static const Color borderSoft = Color(0xFFF0F2F5); // divisores internos
  static const Color borderSofter = Color(0xFFF5F6F8);

  // ── Semantic ───────────────────────────────────────────────────────────────
  static const Color success = Color(0xFF0E9F6E);
  static const Color successLight = Color(0xFFE7F6EF);
  static const Color warning = Color(0xFFB54708);
  static const Color warningLight = Color(0xFFFDF3E1);
  static const Color error = Color(0xFFD92D20); // danger
  static const Color errorLight = Color(0xFFFEE4E2);
  static const Color info = Color(0xFF3E63DD);
  static const Color infoLight = Color(0xFFEFF4FF);

  // ── WhatsApp ───────────────────────────────────────────────────────────────
  static const Color whatsapp = Color(0xFF25D366);
  static const Color whatsappHover = Color(0xFF1FB558);

  // ── Coordenação (cor identificadora) ───────────────────────────────────────
  static const Color roxo = Color(0xFF6D46C7);

  // ── Status badges (mapeados dos status do sistema) ─────────────────────────
  static const Color statusNew = Color(0xFF3E63DD); // Novo visitante
  static const Color statusFollowing = Color(0xFFB54708); // Em acompanhamento
  static const Color statusIntegrated = Color(0xFF0E9F6E); // Integrado
  static const Color statusInactive = Color(0xFF667085); // Não retornou

  // ── Surface & Background — Light ───────────────────────────────────────────
  static const Color background = Color(0xFFEEF0F4); // page bg
  static const Color surface = Color(0xFFFFFFFF); // cards, modais, topbar
  static const Color surfaceVariant = Color(0xFFF9FAFB); // surface-2
  static const Color divider = Color(0xFFE9ECF2);

  // ── Surface & Background — Dark ────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF0A101F);
  static const Color surfaceDark = Color(0xFF131C31);
  static const Color surfaceVariantDark = Color(0xFF0F1829); // surface-2
  static const Color chipDark = Color(0xFF1D2F55);
  static const Color chip2Dark = Color(0xFF1A2B4E);
  static const Color dividerDark = Color(0xFF283755);
  static const Color borderSoftDark = Color(0xFF1E2B45);

  // ── Text — Dark ────────────────────────────────────────────────────────────
  static const Color textDark = Color(0xFFF2F5FA);
  static const Color text2Dark = Color(0xFFC9D3E0);
  static const Color text3Dark = Color(0xFF97A5B8);
  static const Color mutedDark = Color(0xFF697A92);

  // ── Dark mode badge tokens ─────────────────────────────────────────────────
  static const Color infoDarkBg = Color(0xFF1D2F55);
  static const Color infoDarkFg = Color(0xFF93B4FD);
  static const Color successDarkBg = Color(0xFF0E3A2C);
  static const Color successDarkFg = Color(0xFF57D9A3);
  static const Color warningDarkBg = Color(0xFF3F2D10);
  static const Color warningDarkFg = Color(0xFFF2C063);
  static const Color errorDarkBg = Color(0xFF48211C);
  static const Color errorDarkFg = Color(0xFFF4A79D);
  static const Color neutralDarkBg = Color(0xFF26303F);
  static const Color neutralDarkFg = Color(0xFFAEB9C9);
  static const Color primaryDarkBadgeBg = Color(0xFF1D2F55);
  static const Color primaryDarkBadgeFg = Color(0xFF93B4FD);

  // ── Gráficos (dark) ────────────────────────────────────────────────────────
  static const Color chartBlue = Color(0xFF5B8DEF); // total
  static const Color chartGreen = Color(0xFF2FBE8F); // integrados

  // ── Text — Light ───────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF101828);
  static const Color textSecondary = Color(0xFF475467);
  static const Color textTertiary = Color(0xFF667085);
  static const Color textMuted = Color(0xFF98A2B3);
  static const Color textDisabled = Color(0xFF98A2B3);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // ── Gradiente navy (login / sidebar / painéis de marca) ────────────────────
  static const LinearGradient brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navy900, navy800, primary],
  );

  static const LinearGradient sidebarGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [navy900, navy850],
  );

  /// Fundo do item ativo da sidebar (dourado translúcido).
  static const Color sidebarActiveBg = Color(0x24E8A33D); // rgba(232,163,61,.14)

  /// Overlay de modais.
  static const Color modalOverlay = Color(0x730B1530); // rgba(11,21,48,.45)

  // Utility
  static const Color transparent = Colors.transparent;
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
}
