import 'package:flutter/material.dart';
import '../../colors/app_colors.dart';
import '../../spacing/app_spacing.dart';
import '../../typography/app_typography.dart';

enum AppBadgeVariant { info, success, warning, error, neutral, primary }

/// Design System — Status Badge / Chip
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.variant = AppBadgeVariant.info,
    this.icon,
    this.size = AppBadgeSize.md,
  });

  final String label;
  final AppBadgeVariant variant;
  final IconData? icon;
  final AppBadgeSize size;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _colorsFor(variant, isDark);
    final isSmall = size == AppBadgeSize.sm;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? AppSpacing.sm : AppSpacing.md,
        vertical: isSmall ? 2 : AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: isSmall ? 12 : 14, color: colors.foreground),
            const SizedBox(width: AppSpacing.xs),
          ],
          Text(
            label,
            style:
                (isSmall ? AppTypography.labelSmall : AppTypography.labelMedium)
                    .copyWith(
                      color: colors.foreground,
                      fontWeight: FontWeight.w600,
                    ),
          ),
        ],
      ),
    );
  }

  _BadgeColors _colorsFor(AppBadgeVariant v, bool isDark) => switch (v) {
    AppBadgeVariant.info => _BadgeColors(
      background: isDark ? AppColors.infoDarkBg : AppColors.infoLight,
      foreground: isDark ? AppColors.infoDarkFg : AppColors.info,
    ),
    AppBadgeVariant.success => _BadgeColors(
      background: isDark ? AppColors.successDarkBg : AppColors.successLight,
      foreground: isDark ? AppColors.successDarkFg : AppColors.success,
    ),
    AppBadgeVariant.warning => _BadgeColors(
      background: isDark ? AppColors.warningDarkBg : AppColors.warningLight,
      foreground: isDark ? AppColors.warningDarkFg : AppColors.warning,
    ),
    AppBadgeVariant.error => _BadgeColors(
      background: isDark ? AppColors.errorDarkBg : AppColors.errorLight,
      foreground: isDark ? AppColors.errorDarkFg : AppColors.error,
    ),
    AppBadgeVariant.neutral => _BadgeColors(
      background: isDark ? AppColors.neutralDarkBg : AppColors.grey100,
      foreground: isDark ? AppColors.neutralDarkFg : AppColors.grey600,
    ),
    AppBadgeVariant.primary => _BadgeColors(
      background: isDark
          ? AppColors.primaryDarkBadgeBg
          : AppColors.primarySurface,
      foreground: isDark ? AppColors.primaryDarkBadgeFg : AppColors.primary,
    ),
  };
}

enum AppBadgeSize { sm, md }

class _BadgeColors {
  const _BadgeColors({required this.background, required this.foreground});
  final Color background;
  final Color foreground;
}

/// Visitor status badge — maps domain status to badge variant
class VisitorStatusBadge extends StatelessWidget {
  const VisitorStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, variant) = switch (status.toLowerCase()) {
      'novo' || 'new' => ('Novo', AppBadgeVariant.info),
      'em_acompanhamento' ||
      'following' => ('Em acompanhamento', AppBadgeVariant.warning),
      'integrado' || 'integrated' => ('Integrado', AppBadgeVariant.success),
      'inativo' ||
      'inactive' ||
      'nao_retornou' => ('Não retornou', AppBadgeVariant.neutral),
      _ => (status, AppBadgeVariant.neutral),
    };

    return AppBadge(label: label, variant: variant);
  }
}
