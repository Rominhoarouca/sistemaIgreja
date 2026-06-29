import 'package:flutter/material.dart';
import '../../colors/app_colors.dart';
import '../../spacing/app_spacing.dart';
import '../../typography/app_typography.dart';
import '../buttons/app_button.dart';

/// Reusable empty-state widget that shows the app logo, a headline and an
/// optional call-to-action button.
///
/// Usage:
/// ```dart
/// AppEmptyState(
///   message: 'Nenhum encontro registrado',
///   hint: 'Crie um novo encontro para começar.',
///   actionLabel: 'Criar encontro',
///   onAction: () {},
/// )
/// ```
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.message,
    this.hint,
    this.actionLabel,
    this.onAction,
    this.icon,
  });

  /// Main headline shown below the logo.
  final String message;

  /// Optional secondary text providing context or instructions.
  final String? hint;

  /// Label for the optional action button.
  final String? actionLabel;

  /// Callback for the optional action button.
  final VoidCallback? onAction;

  /// Custom icon to show instead of the default logo.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xl2,
          vertical: AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo / icon area
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: icon != null
                  ? Icon(icon, size: 48, color: AppColors.primary)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Image.asset(
                        'assets/images/logo App.png',
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.church_outlined,
                          size: 48,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              message,
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            if (hint != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                hint!,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: actionLabel!,
                variant: AppButtonVariant.outline,
                isFullWidth: false,
                prefixIcon: Icons.add,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
