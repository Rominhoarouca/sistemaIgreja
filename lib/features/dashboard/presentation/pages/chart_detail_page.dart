import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../design_system/design_system.dart';

/// Data model for a single row in the chart detail table.
class ChartDataRow {
  const ChartDataRow({required this.label, required this.values});

  final String label;
  final List<ChartValue> values;
}

class ChartValue {
  const ChartValue({required this.header, required this.value, this.color});

  final String header;
  final String value;
  final Color? color;
}

/// Generic full-screen detail view for any chart.
/// Shows an enlarged chart + a sortable data table beneath.
class ChartDetailPage extends StatefulWidget {
  const ChartDetailPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.chartBuilder,
    required this.columns,
    required this.rows,
    this.legendItems = const [],
  });

  /// Page title (e.g. "Crescimento de Integração")
  final String title;

  /// Optional subtitle shown under the title
  final String subtitle;

  /// Widget that renders the chart (will receive a larger bounding box)
  final Widget chartBuilder;

  /// Column headers for the table
  final List<String> columns;

  /// Table rows
  final List<ChartDataRow> rows;

  /// Optional color legend items shown below the chart
  final List<({Color color, String label})> legendItems;

  @override
  State<ChartDetailPage> createState() => _ChartDetailPageState();
}

class _ChartDetailPageState extends State<ChartDetailPage> {
  int _sortColumnIndex = 0;
  bool _sortAscending = true;
  late List<ChartDataRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = List.from(widget.rows);
  }

  void _sort(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _sortAscending = true;
      }
      _rows.sort((a, b) {
        String valA;
        String valB;
        if (columnIndex == 0) {
          valA = a.label;
          valB = b.label;
        } else {
          final valueIndex = columnIndex - 1;
          valA = a.values.length > valueIndex ? a.values[valueIndex].value : '';
          valB = b.values.length > valueIndex ? b.values[valueIndex].value : '';
        }
        // Try numeric comparison first
        final numA = num.tryParse(valA.replaceAll('%', '').trim());
        final numB = num.tryParse(valB.replaceAll('%', '').trim());
        int cmp;
        if (numA != null && numB != null) {
          cmp = numA.compareTo(numB);
        } else {
          cmp = valA.compareTo(valB);
        }
        return _sortAscending ? cmp : -cmp;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: AppTypography.titleLarge),
            if (widget.subtitle.isNotEmpty)
              Text(
                widget.subtitle,
                style: AppTypography.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        children: [
          // ── Enlarged Chart ──────────────────────────────────────────
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                widget.chartBuilder,
                if (widget.legendItems.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.base,
                    runSpacing: AppSpacing.xs,
                    children: widget.legendItems
                        .map(
                          (item) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 14,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: item.color,
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                item.label,
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Summary Stat Row ────────────────────────────────────────
          if (widget.rows.isNotEmpty) ...[
            AppSectionHeader(title: 'Dados Detalhados (${widget.rows.length})'),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              padding: EdgeInsets.zero,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  sortColumnIndex: _sortColumnIndex,
                  sortAscending: _sortAscending,
                  headingRowColor: WidgetStateProperty.all(
                    AppColors.primarySurface,
                  ),
                  dividerThickness: 0.5,
                  columnSpacing: AppSpacing.xl,
                  columns: [
                    DataColumn(
                      label: Text(
                        widget.columns.isNotEmpty ? widget.columns[0] : 'Item',
                        style: AppTypography.labelMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      onSort: (idx, _) => _sort(idx),
                    ),
                    ...widget.columns
                        .skip(1)
                        .toList()
                        .asMap()
                        .entries
                        .map(
                          (e) => DataColumn(
                            label: Text(
                              e.value,
                              style: AppTypography.labelMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            numeric: true,
                            onSort: (idx, _) => _sort(idx),
                          ),
                        ),
                  ],
                  rows: _rows.map((row) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(row.label, style: AppTypography.bodyMedium),
                        ),
                        ...row.values.map(
                          (v) => DataCell(
                            v.color != null
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: v.color,
                                          borderRadius: BorderRadius.circular(
                                            2,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.xs),
                                      Text(
                                        v.value,
                                        style: AppTypography.bodyMedium,
                                      ),
                                    ],
                                  )
                                : Text(
                                    v.value,
                                    style: AppTypography.bodyMedium,
                                  ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl2),
        ],
      ),
    );
  }
}

// ── Helpers to build standard chart builders ─────────────────────────────────

/// A tappable wrapper for any chart that navigates to [ChartDetailPage].
class TappableChart extends StatelessWidget {
  const TappableChart({
    super.key,
    required this.child,
    required this.detailTitle,
    required this.detailSubtitle,
    required this.detailChart,
    required this.columns,
    required this.rows,
    this.legendItems = const [],
  });

  final Widget child;
  final String detailTitle;
  final String detailSubtitle;
  final Widget detailChart;
  final List<String> columns;
  final List<ChartDataRow> rows;
  final List<({Color color, String label})> legendItems;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => ChartDetailPage(
                      title: detailTitle,
                      subtitle: detailSubtitle,
                      chartBuilder: detailChart,
                      columns: columns,
                      rows: rows,
                      legendItems: legendItems,
                    ),
                  ),
                );
              },
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.open_in_full,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Ver detalhes',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Enlarged chart variants ───────────────────────────────────────────────────

/// Enlarged line chart for use inside ChartDetailPage.
class DetailLineChart extends StatelessWidget {
  const DetailLineChart({super.key, required this.months});

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
        : (spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) * 1.3)
              .ceilToDouble();

    return SizedBox(
      height: 260,
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
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (spots) => spots
                    .map(
                      (s) => LineTooltipItem(
                        '${s.y.toInt()}',
                        AppTypography.labelSmall.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
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
                  reservedSize: 32,
                  getTitlesWidget: (value, _) => Text(
                    '${value.toInt()}',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
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
                          fontSize: 10,
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
                barWidth: 3,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.primary,
                    strokeWidth: 2,
                    strokeColor: AppColors.white,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  color: AppColors.primary.withValues(alpha: 0.1),
                ),
              ),
              LineChartBarData(
                spots: intSpots,
                isCurved: true,
                color: AppColors.success,
                barWidth: 2.5,
                dotData: FlDotData(
                  show: true,
                  getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                    radius: 4,
                    color: AppColors.success,
                    strokeWidth: 2,
                    strokeColor: AppColors.white,
                  ),
                ),
                dashArray: [4, 3],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Enlarged bar chart for use inside ChartDetailPage.
class DetailBarChart extends StatelessWidget {
  const DetailBarChart({super.key, required this.months});

  final List<Map<String, dynamic>> months;

  @override
  Widget build(BuildContext context) {
    final maxY = months.isEmpty
        ? 10.0
        : (months
                      .map((m) => (m['total'] as num).toDouble())
                      .reduce((a, b) => a > b ? a : b) *
                  1.3)
              .ceilToDouble();

    return SizedBox(
      height: 260,
      child: Padding(
        padding: const EdgeInsets.only(
          top: AppSpacing.base,
          right: AppSpacing.base,
          bottom: AppSpacing.sm,
        ),
        child: BarChart(
          BarChartData(
            maxY: maxY,
            barTouchData: BarTouchData(
              enabled: true,
              touchTooltipData: BarTouchTooltipData(
                getTooltipItem: (group, _, rod, rodIndex) {
                  final label = rodIndex == 0 ? 'Total' : 'Integrados';
                  return BarTooltipItem(
                    '$label: ${rod.toY.toInt()}',
                    AppTypography.labelSmall.copyWith(color: AppColors.white),
                  );
                },
              ),
            ),
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
                  reservedSize: 32,
                  getTitlesWidget: (value, _) => Text(
                    '${value.toInt()}',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 10,
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
                    final label = (months[idx]['month'] as String).substring(5);
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        label,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 10,
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
                    width: 14,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                  BarChartRodData(
                    toY: integrated,
                    color: AppColors.success,
                    width: 14,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
                barsSpace: 4,
              );
            }),
          ),
        ),
      ),
    );
  }
}
