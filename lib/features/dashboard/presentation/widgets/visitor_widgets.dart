import 'package:flutter/material.dart';
import '../../../../design_system/design_system.dart';
import '../utils/snackbar_helper.dart';

/// Tile da listagem de visitantes (admin) — mesmo layout do `AttendeeCard`
/// usado na aba Frequentadores do líder: avatar, nome, linha de contato,
/// badge de status e uma faixa inferior. Não tem frequência de presença (o
/// endpoint `/visitors` é da igreja inteira, não de uma célula) — a faixa
/// mostra há quanto tempo o cadastro existe, no lugar.
class VisitorAdminTile extends StatelessWidget {
  const VisitorAdminTile({
    super.key,
    required this.name,
    required this.status,
    required this.time,
    required this.onTap,
    this.timeLabel = 'Cadastrado',
    this.birthDate,
    this.phone,
    this.email,
  });

  final String name;
  final String status;
  final String time;

  /// Prefixo da linha de rodapé. Nem toda tela mostra data ali — o dashboard
  /// exibe a célula, e "Cadastrado Sem célula" saía como frase quebrada.
  /// String vazia imprime só [time].
  final String timeLabel;
  final VoidCallback onTap;
  final DateTime? birthDate;
  final String? phone;
  final String? email;

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return '?';
    return parts.map((p) => p[0].toUpperCase()).take(2).join();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(initials: _initials),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.titleSmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _ContactLine(
                      birthDate: birthDate,
                      phone: phone,
                      email: email,
                      color: mutedColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  VisitorStatusBadge(status: status),
                  const SizedBox(height: AppSpacing.xs),
                  Icon(Icons.chevron_right, size: 20, color: mutedColor),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _RegisteredStrip(time: time, timeLabel: timeLabel, isDark: isDark),
        ],
      ),
    );
  }
}

/// Aniversário · telefone · e-mail. Quebra em várias linhas em telas estreitas.
class _ContactLine extends StatelessWidget {
  const _ContactLine({
    required this.birthDate,
    required this.phone,
    required this.email,
    required this.color,
  });

  final DateTime? birthDate;
  final String? phone;
  final String? email;
  final Color color;

  static String _dayMonth(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m';
  }

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.bodySmall.copyWith(color: color);
    final items = <(IconData, String)>[
      if (birthDate != null) (Icons.cake_outlined, _dayMonth(birthDate!)),
      if (phone != null && phone!.isNotEmpty) (Icons.phone_outlined, phone!),
      if (email != null && email!.isNotEmpty) (Icons.email_outlined, email!),
    ];

    if (items.isEmpty) {
      return Text('Sem contato cadastrado', style: style);
    }

    // Dentro de um Wrap os filhos recebem largura ilimitada, então um e-mail
    // longo estouraria o card sem o LayoutBuilder + Flexible abaixo.
    return LayoutBuilder(
      builder: (context, constraints) => Wrap(
        spacing: AppSpacing.md,
        runSpacing: AppSpacing.xs,
        children: [
          for (final (icon, text) in items)
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      text,
                      style: style,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Faixa inferior do card — equivalente visual à faixa de frequência do
/// líder, mas sem métrica de presença: aqui só cabe "cadastrado há X".
class _RegisteredStrip extends StatelessWidget {
  const _RegisteredStrip({
    required this.time,
    required this.isDark,
    this.timeLabel = 'Cadastrado',
  });

  final String time;
  final String timeLabel;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceVariantDark : AppColors.grey50,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time, size: 14, color: mutedColor),
          const SizedBox(width: AppSpacing.xs),
          Text(
            timeLabel.isEmpty ? time : '$timeLabel $time',
            style: AppTypography.labelMedium.copyWith(color: mutedColor),
          ),
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
