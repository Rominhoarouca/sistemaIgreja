import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../design_system/design_system.dart';
import 'month_label.dart';

/// SRP: responsável apenas por renderizar o gráfico de barras mensais.
class MonthlyBarChart extends StatelessWidget {
  const MonthlyBarChart({super.key, required this.months});

  final List<Map<String, dynamic>> months;

  @override
  Widget build(BuildContext context) {
    final maxY = months.isEmpty
        ? 10.0
        : (months
                      .map((m) => (m['total'] as num).toDouble())
                      .reduce((a, b) => a > b ? a : b) *
                  1.2)
              .ceilToDouble();

    return SizedBox(
      height: 200,
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.base,
          right: AppSpacing.base,
          bottom: AppSpacing.sm,
        ),
        child: BarChart(
          BarChartData(
            maxY: maxY,
            barTouchData: BarTouchData(enabled: true),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) =>
                  FlLine(color: AppColors.grey300, strokeWidth: 0.5),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  getTitlesWidget: (value, _) => Text(
                    '${value.toInt()}',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 9,
                    ),
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, _) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= months.length) {
                      return const SizedBox.shrink();
                    }
                    final label = monthAxisLabel(months[idx]['month']);
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        label,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 9,
                        ),
                      ),
                    );
                  },
                ),
              ),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
            ),
            barGroups: List.generate(months.length, (i) {
              final total = (months[i]['total'] as num).toDouble();
              final integrated = (months[i]['integrated'] as num).toDouble();
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: total,
                    color: AppColors.primary,
                    width: 10,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                  BarChartRodData(
                    toY: integrated,
                    color: AppColors.success,
                    width: 10,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                  ),
                ],
                barsSpace: 3,
              );
            }),
          ),
        ),
      ),
    );
  }
}
