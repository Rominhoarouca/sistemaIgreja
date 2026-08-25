import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../data/services/dashboard_service.dart';
import '../../domain/exceptions/service_exception.dart';
import '../../domain/services/i_dashboard_service.dart';
import '../widgets/integration_line_chart.dart';
import 'chart_detail_page.dart';
import 'admin_dashboard_sheets.dart';
import 'report_metric_detail_page.dart';
import '../widgets/visitor_widgets.dart';
import '../../../../injection/injection.dart';

/// SRP: responsável apenas por exibir a aba de overview do dashboard.
/// DIP: depende de IDashboardService, não de Dio diretamente.
class DashboardTab extends StatefulWidget {
  const DashboardTab({super.key, required this.onSwitchTab});

  final void Function(int) onSwitchTab;

  @override
  State<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<DashboardTab> {
  late final IDashboardService _dashboardService;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _months = [];
  List<Map<String, dynamic>> _cells = [];
  List<Map<String, dynamic>> _recentVisitors = [];

  @override
  void initState() {
    super.initState();
    _dashboardService = DashboardService(getIt<DioClient>().dio);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final dio = getIt<DioClient>().dio;
      final results = await Future.wait([
        _dashboardService.getStats(),
        _dashboardService.getMonthlyStats(),
        dio.get('/cells'),
        dio.get('/visitors'),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _months = results[1] as List<Map<String, dynamic>>;
        final resp = results[2] as Response<dynamic>;
        _cells = ((resp.data as Map<String, dynamic>)['cells'] as List)
            .cast<Map<String, dynamic>>();
        final visitorsResp = results[3] as Response<dynamic>;
        _recentVisitors =
            ((visitorsResp.data as Map<String, dynamic>)['data'] as List)
                .cast<Map<String, dynamic>>()
                .take(5)
                .toList();
        _loading = false;
      });
    } on ServiceException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar dashboard';
        _loading = false;
      });
    }
  }

  static String _dayLabel(String dayOfWeek) => switch (dayOfWeek) {
    'segunda' => 'Segunda-feira',
    'terca' => 'Terça-feira',
    'quarta' => 'Quarta-feira',
    'quinta' => 'Quinta-feira',
    'sexta' => 'Sexta-feira',
    'sabado' => 'Sábado',
    'domingo' => 'Domingo',
    _ => 'Dia não informado',
  };

  void _openMetricDetail(ReportMetric metric, String headerValue) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ReportMetricDetailPage(metric: metric, headerValue: headerValue),
      ),
    );
  }

  void _showSheet(BuildContext context, Widget sheet) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => sheet,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: AppSpacing.base),
            AppButton(
              label: 'Tentar novamente',
              variant: AppButtonVariant.outline,
              isFullWidth: false,
              onPressed: _loadData,
            ),
          ],
        ),
      );
    }

    final highlightedCells = _cells.take(3).toList();
    final totalVisitors = _stats['totalVisitors'] as int? ?? 0;
    final forwarded = _stats['forwardedVisitors'] as int? ?? 0;
    final integrated = _stats['integratedVisitors'] as int? ?? 0;
    final avgAttendance = _stats['averageAttendanceRate'] as num? ?? 0;

    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: EdgeInsets.all(
          isDesktop ? AppSpacing.pagePaddingV : AppSpacing.pagePaddingH,
        ),
        children: [
          GridView.custom(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: isDesktop ? 4 : 2,
              crossAxisSpacing: AppSpacing.base,
              mainAxisSpacing: AppSpacing.base,
              mainAxisExtent: 148,
            ),
            childrenDelegate: SliverChildListDelegate([
              StatCard(
                label: 'Visitantes Cadastrados',
                value: '$totalVisitors',
                icon: Icons.people_outline,
                color: AppColors.primary,
                onTap: () => _openMetricDetail(
                  ReportMetric.totalVisitors,
                  '$totalVisitors',
                ),
              ),
              StatCard(
                label: 'Encaminhamentos',
                value: '$forwarded',
                icon: Icons.send_outlined,
                color: AppColors.secondary,
                onTap: () => _openMetricDetail(
                  ReportMetric.forwardedVisitors,
                  '$forwarded',
                ),
              ),
              StatCard(
                label: 'Visitantes Integrados',
                value: '$integrated',
                icon: Icons.check_circle_outline,
                color: AppColors.success,
                onTap: () => _openMetricDetail(
                  ReportMetric.integratedVisitors,
                  '$integrated',
                ),
              ),
              StatCard(
                label: 'Frequência nas Células',
                value: '${avgAttendance.toStringAsFixed(1)}%',
                icon: Icons.bar_chart_outlined,
                color: AppColors.accent,
                onTap: () => _openMetricDetail(
                  ReportMetric.avgAttendance,
                  '${avgAttendance.toStringAsFixed(1)}%',
                ),
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppSectionHeader(
            title: 'Visitantes recentes',
            actionLabel: 'Ver todos',
            onAction: () => widget.onSwitchTab(1),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_recentVisitors.isEmpty)
            AppCard(
              child: Text(
                'Nenhum visitante cadastrado ainda.',
                style: AppTypography.bodyMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ..._recentVisitors.map(
              (v) => VisitorAdminTile(
                name: (v['name'] as String?) ?? '—',
                status: (v['status'] as String?) ?? AppConstants.statusNew,
                time: (v['cellName'] as String?) ?? 'Sem célula',
                onTap: () => widget.onSwitchTab(1),
              ),
            ),
          const SizedBox(height: AppSpacing.base),
          AppSectionHeader(
            title: 'Funil de integração',
            actionLabel: 'Ver relatório',
            onAction: () => widget.onSwitchTab(3),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                _FunnelBar(
                  label: 'Cadastrados',
                  value: totalVisitors,
                  max: totalVisitors,
                ),
                const SizedBox(height: AppSpacing.md),
                _FunnelBar(
                  label: 'Encaminhados',
                  value: forwarded,
                  max: totalVisitors,
                ),
                const SizedBox(height: AppSpacing.md),
                _FunnelBar(
                  label: 'Integrados',
                  value: integrated,
                  max: totalVisitors,
                  color: AppColors.success,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          AppSectionHeader(title: 'Crescimento de Integração'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: _months.isEmpty
                ? SizedBox(
                    height: 160,
                    child: Center(
                      child: Text(
                        'Sem dados de visitantes ainda.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                : TappableChart(
                    detailTitle: 'Crescimento de Integração',
                    detailSubtitle: 'Total de visitantes vs integrados por mês',
                    detailChart: DetailLineChart(months: _months),
                    columns: const ['Mês', 'Total', 'Integrados', 'Taxa'],
                    rows: _months.map((m) {
                      final total = (m['total'] as num?)?.toInt() ?? 0;
                      final integ = (m['integrated'] as num?)?.toInt() ?? 0;
                      final rate = total == 0
                          ? '0%'
                          : '${(integ / total * 100).toStringAsFixed(1)}%';
                      return ChartDataRow(
                        label: (m['month'] as String?) ?? '',
                        values: [
                          ChartValue(
                            header: 'Total',
                            value: '$total',
                            color: AppColors.primary,
                          ),
                          ChartValue(
                            header: 'Integrados',
                            value: '$integ',
                            color: AppColors.success,
                          ),
                          ChartValue(header: 'Taxa', value: rate),
                        ],
                      );
                    }).toList(),
                    legendItems: const [
                      (color: AppColors.primary, label: 'Total'),
                      (color: AppColors.success, label: 'Integrados'),
                    ],
                    child: IntegrationLineChart(months: _months),
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppSectionHeader(
            title: 'Células Ativas',
            actionLabel: 'Gerenciar',
            onAction: () => widget.onSwitchTab(2),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: highlightedCells.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(AppSpacing.base),
                    child: Text(
                      'Nenhuma célula cadastrada.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : Column(
                    children: List.generate(highlightedCells.length, (index) {
                      final cell = highlightedCells[index];
                      return Column(
                        children: [
                          _DashboardCellRow(
                            name: (cell['name'] as String?) ?? 'Célula',
                            leader:
                                (cell['leaderName'] as String?) ?? 'Sem líder',
                            day: _dayLabel(
                              (cell['dayOfWeek'] as String?) ?? '',
                            ),
                            status: 'Ativa',
                          ),
                          if (index < highlightedCells.length - 1)
                            const Divider(height: 1),
                        ],
                      );
                    }),
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppSectionHeader(title: 'Ações Rápidas'),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: 'Nova Célula',
                  variant: AppButtonVariant.secondary,
                  prefixIcon: Icons.add_circle_outline,
                  onPressed: () => _showSheet(
                    context,
                    NewCellSheet(dio: getIt<DioClient>().dio),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'Novo Líder',
                  variant: AppButtonVariant.secondary,
                  prefixIcon: Icons.person_add_outlined,
                  onPressed: () => _showSheet(
                    context,
                    NewLeaderSheet(dio: getIt<DioClient>().dio),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl2),
        ],
      ),
    );
  }
}

// ── Private widgets ──────────────────────────────────────────────────────────

/// Barra horizontal do funil de integração.
class _FunnelBar extends StatelessWidget {
  const _FunnelBar({
    required this.label,
    required this.value,
    required this.max,
    this.color,
  });

  final String label;
  final int value;
  final int max;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final barColor =
        color ?? (isDark ? AppColors.chartBlue : AppColors.primary);
    final fraction = max <= 0 ? 0.0 : (value / max).clamp(0.0, 1.0);
    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: Stack(
              children: [
                Container(
                  height: 10,
                  color: isDark ? AppColors.chip2Dark : AppColors.borderSoft,
                ),
                FractionallySizedBox(
                  widthFactor: fraction,
                  child: Container(height: 10, color: barColor),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        SizedBox(
          width: 36,
          child: Text(
            '$value',
            textAlign: TextAlign.end,
            style: AppTypography.labelLarge.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _DashboardCellRow extends StatelessWidget {
  const _DashboardCellRow({
    required this.name,
    required this.leader,
    required this.day,
    required this.status,
  });

  final String name;
  final String leader;
  final String day;
  final String status;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(name, style: AppTypography.titleSmall)),
          Expanded(
            flex: 2,
            child: Text(
              leader,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              day,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          AppBadge(
            label: status,
            variant: AppBadgeVariant.success,
            size: AppBadgeSize.sm,
          ),
        ],
      ),
    );
  }
}
