import 'package:flutter/material.dart';
import '../../colors/app_colors.dart';
import '../../shadows/app_shadows.dart';
import '../../spacing/app_spacing.dart';

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

/// Stat Card — used in Dashboard
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color = AppColors.primary,
    this.subtitle,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AppCard(
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
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: Icon(icon, color: color, size: AppSpacing.iconMd),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
