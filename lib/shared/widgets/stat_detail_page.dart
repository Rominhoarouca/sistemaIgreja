import 'package:flutter/material.dart';
import '../../design_system/design_system.dart';

/// Detalhe de um KPI clicado em um dashboard (líder, supervisor, coordenador):
/// header com a métrica + tabela com os dados locais que compõem o número.
///
/// Diferente do `ReportMetricDetailPage` (admin), esta tela não consulta a
/// API — recebe os dados já carregados pelo dashboard de origem.
class StatDetailPage extends StatelessWidget {
  const StatDetailPage({
    super.key,
    required this.title,
    required this.icon,
    required this.headerValue,
    required this.subtitle,
    required this.columns,
    required this.rows,
  });

  final String title;
  final IconData icon;

  /// Valor exibido no card clicado (repetido no header do detalhe).
  final String headerValue;
  final String subtitle;
  final List<String> columns;
  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        children: [
          // ── Header da métrica clicada ─────────────────────────────────
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                  child: Icon(
                    icon,
                    color: theme.brightness == Brightness.dark
                        ? AppColors.linkDark
                        : AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.base),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        headerValue,
                        style: AppTypography.kpiValueMobile.copyWith(
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            subtitle,
            style: AppTypography.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // ── Grid de dados ─────────────────────────────────────────────
          if (rows.isEmpty)
            const AppEmptyState(
              title: 'Sem dados para exibir',
              subtitle: 'Nenhum registro encontrado para esta métrica.',
              icon: Icons.table_chart_outlined,
            )
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth:
                        MediaQuery.sizeOf(context).width -
                        AppSpacing.pagePaddingH * 2 -
                        2,
                  ),
                  child: DataTable(
                    headingTextStyle: AppTypography.labelLarge.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    dataTextStyle: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurface,
                    ),
                    headingRowColor: WidgetStatePropertyAll(
                      theme.brightness == Brightness.dark
                          ? AppColors.surfaceVariantDark
                          : AppColors.grey50,
                    ),
                    columns: columns
                        .map((c) => DataColumn(label: Text(c)))
                        .toList(),
                    rows: rows
                        .map(
                          (r) => DataRow(
                            cells: r.map((v) => DataCell(Text(v))).toList(),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${rows.length} registro(s)',
            style: AppTypography.labelSmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
