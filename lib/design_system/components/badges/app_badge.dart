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
    final colors = _colorsFor(variant);
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

  _BadgeColors _colorsFor(AppBadgeVariant v) => switch (v) {
    AppBadgeVariant.info => const _BadgeColors(
      background: AppColors.infoLight,
      foreground: AppColors.info,
    ),
    AppBadgeVariant.success => const _BadgeColors(
      background: AppColors.successLight,
      foreground: AppColors.success,
    ),
    AppBadgeVariant.warning => const _BadgeColors(
      background: AppColors.warningLight,
      foreground: AppColors.warning,
    ),
    AppBadgeVariant.error => const _BadgeColors(
      background: AppColors.errorLight,
      foreground: AppColors.error,
    ),
    AppBadgeVariant.neutral => const _BadgeColors(
      background: AppColors.grey100,
      foreground: AppColors.grey600,
    ),
    AppBadgeVariant.primary => const _BadgeColors(
      background: AppColors.primarySurface,
      foreground: AppColors.primary,
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
