import 'package:flutter/material.dart';
import '../../../../design_system/design_system.dart';
import '../utils/snackbar_helper.dart';

/// SRP: tile da listagem de visitantes.
class VisitorAdminTile extends StatelessWidget {
  const VisitorAdminTile({
    super.key,
    required this.name,
    required this.status,
    required this.time,
    required this.onTap,
  });

  final String name;
  final String status;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          AppAvatar(initials: name.split(' ').map((e) => e[0]).take(2).join()),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.titleSmall),
                const SizedBox(height: AppSpacing.xs2),
                Row(
                  children: [
                    VisitorStatusBadge(status: status),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      time,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.grey400),
        ],
      ),
    );
  }
}

/// SRP: chip para alterar status do visitante.
class VisitorStatusChip extends StatelessWidget {
  const VisitorStatusChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: AppTypography.labelMedium),
      onPressed: () => showDashboardSnackBar(
        context,
        'Status alterado para: $label',
        backgroundColor: AppColors.success,
      ),
    );
  }
}
