import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../design_system/design_system.dart';

/// SRP: responsável apenas por renderizar o gráfico de linha de integração.
class IntegrationLineChart extends StatelessWidget {
  const IntegrationLineChart({super.key, required this.months});

  final List<Map<String, dynamic>> months;

  @override
  Widget build(BuildContext context) {
    final spots = <FlSpot>[];
    final intSpots = <FlSpot>[];
    for (var i = 0; i < months.length; i++) {
      spots.add(FlSpot(i.toDouble(), (months[i]['total'] as num).toDouble()));
      intSpots.add(
        FlSpot(i.toDouble(), (months[i]['integrated'] as num).toDouble()),
      );
    }
    final maxY = spots.isEmpty
        ? 10.0
        : (spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.2)
              .ceilToDouble();

    return SizedBox(
      height: 180,
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.base,
          right: AppSpacing.base,
          bottom: AppSpacing.sm,
        ),
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: maxY,
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
                  interval: 1,
                  getTitlesWidget: (value, _) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= months.length) {
                      return const SizedBox.shrink();
                    }
                    final label = (months[idx]['month'] as String).substring(5);
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
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.primary,
                barWidth: 2.5,
                dotData: const FlDotData(show: false),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.primary.withValues(alpha: 0.08),
                ),
              ),
              LineChartBarData(
                spots: intSpots,
                isCurved: true,
                color: AppColors.success,
                barWidth: 2,
                dotData: const FlDotData(show: false),
                dashArray: [4, 3],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
