import 'package:flutter/material.dart';
import '../../../../design_system/design_system.dart';

/// Paleta categórica dos gráficos demográficos.
///
/// Não vive em [AppColors] porque é específica de visualização de dados: os
/// tons foram escolhidos para serem distinguíveis por quem tem daltonismo
/// (deutan/protan/tritan) sobre as superfícies clara e escura do app, e
/// validados nessa condição. Alterar um hex exige revalidar o conjunto.
abstract final class _VizColors {
  static const Color blue = Color(0xFF3E63DD);
  static const Color pink = Color(0xFFC2409B);
  static const Color goldLight = Color(0xFFE8A33D);
  // No escuro o dourado claro estoura a faixa de luminosidade da superfície.
  static const Color goldDark = Color(0xFFC2851C);

  /// Reservado para "Não informado" — cinza de propósito, para ler como
  /// ausência de dado e nunca competir com as categorias reais.
  static const Color unknownLight = AppColors.grey400;
  static const Color unknownDark = AppColors.mutedDark;

  static Color gold(bool isDark) => isDark ? goldDark : goldLight;
  static Color unknown(bool isDark) => isDark ? unknownDark : unknownLight;
}

/// Uma linha do gráfico: rótulo, contagem, percentual e a cor da barra.
class _Bucket {
  const _Bucket({
    required this.key,
    required this.label,
    required this.count,
    required this.percent,
  });

  factory _Bucket.fromJson(Map<String, dynamic> json) => _Bucket(
    key: json['key'] as String? ?? '',
    label: json['label'] as String? ?? '',
    count: (json['count'] as num?)?.toInt() ?? 0,
    percent: (json['percent'] as num?)?.toDouble() ?? 0,
  );

  final String key;
  final String label;
  final int count;
  final double percent;
}

/// Seção "Informações demográficas" do painel do administrador.
///
/// Recebe o payload de `GET /dashboard/demographics` já decodificado. Cada
/// dimensão vira um card com uma linha por faixa: rótulo, contagem, percentual
/// e uma barra proporcional ao percentual sobre o total de pessoas.
class DemographicsSection extends StatelessWidget {
  const DemographicsSection({super.key, required this.demographics});

  /// Payload cru do endpoint: `{ total, gender, ageRange, maritalStatus }`.
  final Map<String, dynamic> demographics;

  static List<_Bucket> _buckets(Map<String, dynamic> json, String key) {
    final raw = json[key] as List?;
    if (raw == null) return const [];
    return raw
        .cast<Map<String, dynamic>>()
        .map(_Bucket.fromJson)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final total = (demographics['total'] as num?)?.toInt() ?? 0;

    final gender = _buckets(demographics, 'gender');
    final ageRange = _buckets(demographics, 'ageRange');
    final maritalStatus = _buckets(demographics, 'maritalStatus');

    // Gênero e estado civil são categorias sem ordem — cores distintas. Faixa
    // etária é ordinal e já está ordenada na vertical, então um único tom
    // evita ruído de cor sem perder a leitura.
    Color genderColor(String key) => switch (key) {
      'MASCULINO' => _VizColors.blue,
      'FEMININO' => _VizColors.pink,
      _ => _VizColors.unknown(isDark),
    };
    Color ageColor(String key) =>
        key == 'UNKNOWN' ? _VizColors.unknown(isDark) : _VizColors.blue;
    Color maritalColor(String key) => switch (key) {
      'MARRIED' => _VizColors.pink,
      'SINGLE' => _VizColors.blue,
      'OTHER' => _VizColors.gold(isDark),
      _ => _VizColors.unknown(isDark),
    };

    final groups = [
      _DemographicGroup(
        icon: Icons.wc_outlined,
        title: 'Gênero',
        buckets: gender,
        colorOf: genderColor,
      ),
      _DemographicGroup(
        icon: Icons.cake_outlined,
        title: 'Faixa etária',
        buckets: ageRange,
        colorOf: ageColor,
      ),
      _DemographicGroup(
        icon: Icons.favorite_outline,
        title: 'Estado civil',
        buckets: maritalStatus,
        colorOf: maritalColor,
      ),
    ];

    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(total: total, isDark: isDark),
          const SizedBox(height: AppSpacing.lg),
          if (total == 0)
            _EmptyState(isDark: isDark)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                // Abaixo de 900px os três cards não caberiam lado a lado sem
                // truncar rótulos como "Não informado".
                final isWide = constraints.maxWidth >= 900;
                if (!isWide) {
                  return Column(
                    children: [
                      for (var i = 0; i < groups.length; i++) ...[
                        if (i > 0) const SizedBox(height: AppSpacing.base),
                        groups[i],
                      ],
                    ],
                  );
                }
                // IntrinsicHeight + stretch deixa os três cards com a altura do
                // maior (faixa etária), como no layout de referência.
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < groups.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.base),
                        Expanded(child: groups[i]),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.total, required this.isDark});

  final int total;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      // Em telas estreitas o subtítulo quebra em várias linhas; alinhado ao
      // topo o ícone continua ao lado do título.
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: isDark ? AppColors.chipDark : AppColors.chip,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
          child: Icon(
            Icons.assignment_ind_outlined,
            size: AppSpacing.iconSm,
            color: isDark ? AppColors.linkDark : AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Informações demográficas', style: AppTypography.titleMedium),
              const SizedBox(height: AppSpacing.xs2),
              Text(
                total == 1
                    ? '1 pessoa (visitantes e membros de célula)'
                    : '$total pessoas (visitantes e membros de célula)',
                style: AppTypography.bodySmall.copyWith(
                  color: isDark ? AppColors.text3Dark : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(
          'Sem pessoas cadastradas ainda.',
          style: AppTypography.bodySmall.copyWith(
            color: isDark ? AppColors.text3Dark : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Card de uma dimensão (Gênero, Faixa etária ou Estado civil).
class _DemographicGroup extends StatelessWidget {
  const _DemographicGroup({
    required this.icon,
    required this.title,
    required this.buckets,
    required this.colorOf,
  });

  final IconData icon;
  final String title;
  final List<_Bucket> buckets;
  final Color Function(String key) colorOf;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      elevation: AppCardElevation.none,
      color: isDark ? AppColors.surfaceVariantDark : AppColors.surfaceVariant,
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: AppSpacing.iconSm,
                color: isDark ? AppColors.linkDark : AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: AppTypography.titleSmall),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(
            height: 1,
            color: isDark ? AppColors.borderSoftDark : AppColors.borderSoft,
          ),
          const SizedBox(height: AppSpacing.md),
          for (var i = 0; i < buckets.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.md),
            _DemographicBar(
              bucket: buckets[i],
              color: colorOf(buckets[i].key),
              isDark: isDark,
            ),
          ],
        ],
      ),
    );
  }
}

/// Uma linha: rótulo + contagem + percentual e a barra proporcional.
class _DemographicBar extends StatelessWidget {
  const _DemographicBar({
    required this.bucket,
    required this.color,
    required this.isDark,
  });

  final _Bucket bucket;
  final Color color;
  final bool isDark;

  static const double _barHeight = 6;

  /// pt-BR usa vírgula decimal: 44.3 → "44,3%".
  static String _formatPercent(double percent) =>
      '${percent.toStringAsFixed(1).replaceAll('.', ',')}%';

  @override
  Widget build(BuildContext context) {
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;
    // Fração do total, limitada a [0,1] para nunca estourar a trilha.
    final fraction = (bucket.percent / 100).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text(
                bucket.label,
                style: AppTypography.bodySmall.copyWith(color: mutedColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '${bucket.count}',
              style: AppTypography.labelLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.textDark : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              '(${_formatPercent(bucket.percent)})',
              style: AppTypography.bodySmall.copyWith(color: mutedColor),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          child: Container(
            height: _barHeight,
            color: isDark ? AppColors.dividerDark : AppColors.grey200,
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
