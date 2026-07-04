/// Design System — Spacing Scale
/// Fonte: design_handoff_sistema_igreja/README.md (forma e espaçamento)
abstract final class AppSpacing {
  static const double xs2 = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double base = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xl2 = 32;
  static const double xl3 = 40;
  static const double xl4 = 48;
  static const double xl5 = 64;
  static const double xl6 = 80;

  // ── Espaçamentos de formulário (handoff) ───────────────────────────────────
  static const double labelGap = 7; // label → input
  static const double fieldGap = 14; // entre campos
  static const double sectionGap = 20; // gaps de seção (16–24)
  static const double cardPadding = 24; // padding de card (20–28)

  // ── Border Radius ──────────────────────────────────────────────────────────
  static const double radiusXs = 4;
  static const double radiusSm = 8;
  static const double radiusMd = 12; // inputs/botões (10–12)
  static const double radiusLg = 16; // cards (14–18)
  static const double radiusXl = 18; // modais
  static const double radiusXl2 = 20; // frame externo
  static const double radiusFull = 999; // chips/badges/avatars (pill)

  // ── Icon sizes ─────────────────────────────────────────────────────────────
  static const double iconXs = 16;
  static const double iconSm = 20;
  static const double iconMd = 24;
  static const double iconLg = 32;
  static const double iconXl = 40;
  static const double iconXl2 = 48;

  // ── Component heights ──────────────────────────────────────────────────────
  static const double buttonHeightSm = 40;
  static const double buttonHeightMd = 48;
  static const double buttonHeightLg = 52;
  static const double inputHeight = 50; // 48–52
  static const double appBarHeight = 68; // topbar
  static const double bottomNavHeight = 82;
  static const double cardMinHeight = 80;
  static const double avatarSm = 32;
  static const double avatarMd = 40;
  static const double avatarLg = 56;
  static const double avatarXl = 80;
  static const double minTouchTarget = 44; // alvo mínimo mobile

  // ── Layout (shell) ─────────────────────────────────────────────────────────
  static const double sidebarWidth = 252;
  static const double topbarHeight = 68;
  static const double detailPanelWidth = 340;
  static const double searchWidth = 300;

  // ── Page padding ───────────────────────────────────────────────────────────
  static const double pagePaddingH = 20;
  static const double pagePaddingV = 24;
}
