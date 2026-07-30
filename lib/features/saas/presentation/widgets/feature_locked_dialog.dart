import 'package:flutter/material.dart';
import '../../../../design_system/design_system.dart';
import '../church_context_controller.dart';

/// Dialog de upsell — mostrado quando o usuário clica num recurso da
/// sidebar que não está incluído no plano atual da igreja. Informa o
/// recurso e a partir de qual plano ele fica disponível.
Future<void> showFeatureLockedDialog(BuildContext context, String featureKey) {
  final ctrl = ChurchContextController.instance;
  final catalogItem = ctrl.featureCatalogItem(featureKey);
  final minPlan = ctrl.minPlanForFeature(featureKey);
  final currentPlanName = ctrl.plan?.name;

  return showDialog<void>(
    context: context,
    builder: (ctx) => _FeatureLockedDialog(
      label: catalogItem?.label ?? featureKey,
      description: catalogItem?.description,
      requiredPlanName: minPlan?.name,
      currentPlanName: currentPlanName,
    ),
  );
}

class _FeatureLockedDialog extends StatelessWidget {
  const _FeatureLockedDialog({
    required this.label,
    this.description,
    this.requiredPlanName,
    this.currentPlanName,
  });

  final String label;
  final String? description;
  final String? requiredPlanName;
  final String? currentPlanName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusXl),
            boxShadow: AppShadows.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Cabeçalho com ícone de cadeado dourado ────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl2,
                  AppSpacing.xl,
                  AppSpacing.lg,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: AppColors.brandGradient,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: AppColors.gold,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTypography.titleMedium.copyWith(
                        color: isDark ? AppColors.textDark : AppColors.textPrimary,
                      ),
                    ),
                    if (description != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        description!,
                        textAlign: TextAlign.center,
                        style: AppTypography.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.text3Dark
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // ── Info do plano ──────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.chipDark : AppColors.chip,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentPlanName != null
                            ? 'Não incluído no plano atual ($currentPlanName)'
                            : 'Não incluído no seu plano atual',
                        style: AppTypography.labelMedium.copyWith(
                          color: isDark ? AppColors.text2Dark : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          Icon(
                            Icons.workspace_premium_rounded,
                            size: 16,
                            color: isDark ? AppColors.linkDark : AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              requiredPlanName != null
                                  ? 'Disponível a partir do plano $requiredPlanName'
                                  : 'Fale com o suporte para saber a disponibilidade',
                              style: AppTypography.labelMedium.copyWith(
                                color: isDark ? AppColors.linkDark : AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // ── Ação ────────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: AppButton(
                  label: 'Entendi',
                  variant: AppButtonVariant.primary,
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
