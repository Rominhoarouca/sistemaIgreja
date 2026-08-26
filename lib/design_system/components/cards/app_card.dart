import 'package:flutter/material.dart';
import '../../colors/app_colors.dart';
import '../../shadows/app_shadows.dart';
import '../../spacing/app_spacing.dart';
import '../../typography/app_typography.dart';

/// Design System — Surface Card (base container)
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.elevation = AppCardElevation.flat,
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final AppCardElevation elevation;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor =
        color ?? (isDark ? AppColors.surfaceDark : AppColors.surface);
    final radius = borderRadius ?? AppSpacing.radiusLg;

    final shadows = switch (elevation) {
      AppCardElevation.none => AppShadows.none,
      AppCardElevation.flat => AppShadows.xs,
      AppCardElevation.raised => AppShadows.md,
      AppCardElevation.floating => AppShadows.lg,
    };

    final container = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadows,
        border: elevation == AppCardElevation.flat
            ? Border.all(
                color: isDark ? AppColors.dividerDark : AppColors.divider,
                width: 1,
              )
            : null,
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(AppSpacing.base),
        child: child,
      ),
    );

    if (onTap == null) return container;

    return GestureDetector(onTap: onTap, child: container);
  }
}

enum AppCardElevation { none, flat, raised, floating }

/// Stat Card (KPI) — used in Dashboard.
/// Valor em Sora 30px (26px em telas estreitas) + delta pill opcional.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
    this.subtitle,
    this.deltaPositive = true,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  /// Delta exibido como pill (ex.: "+12%"). Verde quando [deltaPositive].
  final String? subtitle;
  final bool deltaPositive;

  /// Torna o card clicável (ex.: abrir detalhe da métrica).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final compact = MediaQuery.sizeOf(context).width < 1024;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.chipDark : AppColors.chip,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(
                  icon,
                  color: isDark ? AppColors.linkDark : color,
                  size: AppSpacing.iconSm,
                ),
              ),
              // Flexible + ellipsis: o pill cresce com o texto ("20% integrados"
              // é mais largo que "+12%") e, sem limite, estourava o Row.
              if (subtitle != null)
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: deltaPositive
                          ? (isDark
                                ? AppColors.successDarkBg
                                : AppColors.successLight)
                          : (isDark
                                ? AppColors.errorDarkBg
                                : AppColors.errorLight),
                      borderRadius: BorderRadius.circular(
                        AppSpacing.radiusFull,
                      ),
                    ),
                    child: Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: deltaPositive
                            ? (isDark
                                  ? AppColors.successDarkFg
                                  : AppColors.success)
                            : (isDark
                                  ? AppColors.errorDarkFg
                                  : AppColors.error),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          // Espaçamento menor para caber a segunda linha do rótulo: os grids
          // que hospedam este card fixam a altura em `mainAxisExtent: 148`.
          const SizedBox(height: AppSpacing.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style:
                  (compact
                          ? AppTypography.kpiValueMobile
                          : AppTypography.kpiValue)
                      .copyWith(color: theme.colorScheme.onSurface),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // Duas linhas: rótulos como "Visitantes Cadastrados" e "Frequência
          // nas Células" não cabem em uma só e vinham cortados com reticências.
          // `Flexible` garante que, se ainda assim faltar espaço (fonte
          // ampliada por acessibilidade), o texto seja cortado em vez de
          // estourar o Column.
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
