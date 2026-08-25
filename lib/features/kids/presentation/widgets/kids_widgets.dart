import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../data/kids_models.dart';

/// Mensagem de erro da API em pt-BR, com fallback. O backend do Kids devolve
/// motivos acionáveis ("Sala lotada: 14/14"), então mostrá-los importa mais
/// que um texto genérico.
String kidsErrorMessage(Object error, String fallback) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final err = data['error'];
      if (err is Map && err['message'] is String) {
        return err['message'] as String;
      }
    }
  }
  return fallback;
}

/// Detalhes estruturados que o backend anexa a alguns 409 — por exemplo, quem
/// ainda está na sala quando o fechamento é bloqueado.
Map<String, dynamic>? kidsErrorDetails(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map) {
      final err = data['error'];
      if (err is Map && err['details'] is Map) {
        return Map<String, dynamic>.from(err['details'] as Map);
      }
    }
  }
  return null;
}

/// SnackBar de erro no padrão do módulo.
void showKidsError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: AppColors.error),
  );
}

/// Cores dos níveis de alerta. O rótulo sempre acompanha a cor — âmbar e
/// laranja não se distinguem sozinhos, e aqui errar o nível tem consequência.
Color alertLevelColor(KidsAlertLevel level, {required bool isDark}) =>
    switch (level) {
      KidsAlertLevel.info =>
        isDark ? const Color(0xFF60A5FA) : const Color(0xFF1D4ED8),
      KidsAlertLevel.urgent =>
        isDark ? const Color(0xFFE8A33D) : const Color(0xFFC2851C),
      KidsAlertLevel.emergency =>
        isDark ? const Color(0xFFDC4A3D) : const Color(0xFFD92D20),
    };

AppBadgeVariant alertLevelBadge(KidsAlertLevel level) => switch (level) {
  KidsAlertLevel.info => AppBadgeVariant.info,
  KidsAlertLevel.urgent => AppBadgeVariant.warning,
  KidsAlertLevel.emergency => AppBadgeVariant.error,
};

/// hh:mm.
String formatTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

/// dd/MM/yyyy.
String formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

/// Barra de ocupação da sala: âmbar em 90%, vermelho ao lotar. O número vem
/// junto porque a cor só reforça — não informa quantas vagas restam.
class KidsOccupancyBar extends StatelessWidget {
  const KidsOccupancyBar({
    super.key,
    required this.current,
    required this.capacity,
    this.showLabel = true,
  });

  final int current;
  final int capacity;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;
    final ratio = capacity == 0 ? 0.0 : (current / capacity).clamp(0.0, 1.0);

    final color = ratio >= 1
        ? (isDark ? const Color(0xFFDC4A3D) : const Color(0xFFD92D20))
        : ratio >= 0.9
        ? (isDark ? const Color(0xFFE8A33D) : const Color(0xFFC2851C))
        : (isDark ? const Color(0xFF12B886) : const Color(0xFF047857));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showLabel) ...[
          Row(
            children: [
              Icon(Icons.groups_outlined, size: 14, color: mutedColor),
              const SizedBox(width: AppSpacing.xs),
              Text(
                '$current de $capacity lugares',
                style: AppTypography.bodySmall.copyWith(color: mutedColor),
              ),
              if (ratio >= 1) ...[
                const SizedBox(width: AppSpacing.sm),
                const AppBadge(
                  label: 'Lotada',
                  variant: AppBadgeVariant.error,
                  size: AppBadgeSize.sm,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: Container(
            height: 6,
            color: isDark ? AppColors.dividerDark : AppColors.grey200,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ratio,
              child: DecoratedBox(decoration: BoxDecoration(color: color)),
            ),
          ),
        ),
      ],
    );
  }
}

/// Marcadores de saúde da criança. Vermelho para alergia, âmbar para
/// medicação, azul para deficiência — sempre com o texto junto.
class KidsHealthBadges extends StatelessWidget {
  const KidsHealthBadges({
    super.key,
    required this.health,
    this.compact = false,
  });

  final ChildHealth health;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (health.isEmpty) return const SizedBox.shrink();

    final items = <(String, AppBadgeVariant)>[
      if ((health.allergies ?? '').isNotEmpty)
        ('Alergia: ${health.allergies}', AppBadgeVariant.error),
      if ((health.medications ?? '').isNotEmpty)
        ('Medicação: ${health.medications}', AppBadgeVariant.warning),
      if ((health.disabilities ?? '').isNotEmpty)
        ('Deficiência: ${health.disabilities}', AppBadgeVariant.info),
      if (!compact && (health.medicalNotes ?? '').isNotEmpty)
        (health.medicalNotes!, AppBadgeVariant.neutral),
    ];

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final (label, variant) in items)
          AppBadge(
            label: compact && label.length > 24
                ? '${label.substring(0, 24)}…'
                : label,
            variant: variant,
            size: AppBadgeSize.sm,
          ),
      ],
    );
  }
}

/// Diálogo que mostra a senha de retirada. Aparece **uma vez só** — depois o
/// backend guarda apenas o hash, e recuperá-la exige gerar outra.
class KidsPickupCodeDialog extends StatelessWidget {
  const KidsPickupCodeDialog({
    super.key,
    required this.results,
    required this.roomName,
  });

  final List<KidsCheckinResult> results;
  final String roomName;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;

    return AlertDialog(
      title: const Text('Check-in realizado'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              roomName,
              style: AppTypography.bodySmall.copyWith(color: mutedColor),
            ),
            const SizedBox(height: AppSpacing.md),
            for (final r in results) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceVariantDark
                      : AppColors.grey50,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            r.childName,
                            style: AppTypography.titleSmall,
                          ),
                        ),
                        AppBadge(
                          label: r.badgeCode,
                          variant: AppBadgeVariant.primary,
                          size: AppBadgeSize.sm,
                        ),
                      ],
                    ),
                    if (r.pickupCode != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Senha de retirada',
                        style: AppTypography.bodySmall.copyWith(
                          color: mutedColor,
                        ),
                      ),
                      Text(
                        r.pickupCode!,
                        style: AppTypography.kpiValue.copyWith(
                          letterSpacing: 6,
                        ),
                      ),
                      Text(
                        'Anote e entregue ao responsável — não será exibida de novo.',
                        style: AppTypography.bodySmall.copyWith(
                          color: mutedColor,
                        ),
                      ),
                    ] else ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Retirada pelo QR Code do app do responsável.',
                        style: AppTypography.bodySmall.copyWith(
                          color: mutedColor,
                        ),
                      ),
                    ],
                    if (r.healthFlags.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final flag in r.healthFlags)
                            AppBadge(
                              label: flag,
                              variant: AppBadgeVariant.warning,
                              size: AppBadgeSize.sm,
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Entendi'),
        ),
      ],
    );
  }
}

/// Linha de uma criança na sala.
class KidsChildTile extends StatelessWidget {
  const KidsChildTile({
    super.key,
    required this.checkin,
    required this.onTap,
    this.trailing,
  });

  final KidsCheckin checkin;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppAvatar(initials: _initials(checkin.childName)),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      checkin.childName,
                      style: AppTypography.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      checkin.isPresent
                          ? 'Entrou ${formatTime(checkin.checkinAt)}'
                          : 'Saiu ${checkin.checkoutAt == null ? '' : formatTime(checkin.checkoutAt!)}'
                                '${checkin.checkoutGuardianName == null ? '' : ' · ${checkin.checkoutGuardianName}'}',
                      style: AppTypography.bodySmall.copyWith(
                        color: mutedColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  AppBadge(
                    label: checkin.badgeCode,
                    variant: checkin.isPresent
                        ? AppBadgeVariant.primary
                        : AppBadgeVariant.neutral,
                    size: AppBadgeSize.sm,
                  ),
                  if (checkin.openAlerts > 0) ...[
                    const SizedBox(height: AppSpacing.xs),
                    AppBadge(
                      label: '${checkin.openAlerts} alerta(s)',
                      variant: AppBadgeVariant.error,
                      size: AppBadgeSize.sm,
                    ),
                  ],
                ],
              ),
              if (trailing != null) ...[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
          // Dado clínico só enquanto a criança está na sala — depois do
          // check-out ele sai da tela (§11 da documentação do módulo).
          if (checkin.isPresent && !checkin.health.isEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            KidsHealthBadges(health: checkin.health, compact: true),
          ],
          if (checkin.isPresent && checkin.hasPickupCode) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.key_outlined, size: 14, color: mutedColor),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Senha final ${checkin.pickupCodeLast2 ?? '??'}',
                  style: AppTypography.bodySmall.copyWith(color: mutedColor),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.map((p) => p[0].toUpperCase()).take(2).join();
  }
}
