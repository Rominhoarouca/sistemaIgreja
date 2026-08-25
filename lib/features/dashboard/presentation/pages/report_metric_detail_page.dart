import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../../../injection/injection.dart';

/// Métrica clicada na tela de Relatórios ou no Dashboard.
enum ReportMetric {
  integrationRate,
  activeLeaders,
  visitorsMonth,
  avgAttendance,
  totalVisitors,
  forwardedVisitors,
  integratedVisitors,
}

extension on ReportMetric {
  String get title => switch (this) {
    ReportMetric.integrationRate => 'Taxa de Integração',
    ReportMetric.activeLeaders => 'Líderes Ativos',
    ReportMetric.visitorsMonth => 'Visitantes (mês)',
    ReportMetric.avgAttendance => 'Média Frequência',
    ReportMetric.totalVisitors => 'Visitantes Cadastrados',
    ReportMetric.forwardedVisitors => 'Encaminhamentos',
    ReportMetric.integratedVisitors => 'Visitantes Integrados',
  };

  IconData get icon => switch (this) {
    ReportMetric.integrationRate => Icons.trending_up,
    ReportMetric.activeLeaders => Icons.people,
    ReportMetric.visitorsMonth => Icons.calendar_month_outlined,
    ReportMetric.avgAttendance => Icons.bar_chart,
    ReportMetric.totalVisitors => Icons.people_outline,
    ReportMetric.forwardedVisitors => Icons.send_outlined,
    ReportMetric.integratedVisitors => Icons.check_circle_outline,
  };
}

/// Detalhe de uma métrica de relatório: header com a métrica clicada
/// + grid (tabela) com os dados que compõem o número.
class ReportMetricDetailPage extends StatefulWidget {
  const ReportMetricDetailPage({
    super.key,
    required this.metric,
    required this.headerValue,
  });

  final ReportMetric metric;

  /// Valor exibido no card clicado (repetido no header do detalhe).
  final String headerValue;

  @override
  State<ReportMetricDetailPage> createState() => _ReportMetricDetailPageState();
}

class _ReportMetricDetailPageState extends State<ReportMetricDetailPage> {
  late final Dio _dio;
  bool _loading = true;
  String? _error;
  List<String> _columns = [];
  List<List<String>> _rows = [];
  String _subtitle = '';

  @override
  void initState() {
    super.initState();
    _dio = getIt<DioClient>().dio;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      switch (widget.metric) {
        case ReportMetric.integrationRate:
          await _loadIntegrationRate();
        case ReportMetric.activeLeaders:
          await _loadLeaders();
        case ReportMetric.visitorsMonth:
          await _loadVisitorsMonth();
        case ReportMetric.avgAttendance:
          await _loadAttendanceByCell();
        case ReportMetric.totalVisitors:
          await _loadVisitorsByStatus(
            subtitle: 'Todos os visitantes cadastrados',
          );
        case ReportMetric.forwardedVisitors:
          await _loadVisitorsByStatus(
            statuses: {'em_acompanhamento', 'integrado'},
            subtitle:
                'Visitantes encaminhados (em acompanhamento e integrados)',
          );
        case ReportMetric.integratedVisitors:
          await _loadVisitorsByStatus(
            statuses: {'integrado'},
            subtitle: 'Visitantes integrados à igreja',
          );
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } on DioException catch (e) {
      if (!mounted) return;
      final data = e.response?.data;
      setState(() {
        _error = data is Map
            ? (data['error']?['message'] as String? ?? 'Erro ao carregar dados')
            : 'Erro ao carregar dados (HTTP ${e.response?.statusCode ?? '—'})';
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro inesperado ao processar os dados';
        _loading = false;
      });
    }
  }

  Future<void> _loadIntegrationRate() async {
    final resp = await _dio.get('/dashboard/monthly-stats');
    final months = ((resp.data as Map<String, dynamic>)['months'] as List)
        .cast<Map<String, dynamic>>();
    _subtitle = 'Visitantes cadastrados × integrados por mês (últ. 6 meses)';
    _columns = ['Mês', 'Cadastrados', 'Integrados', 'Taxa'];
    _rows = months.map((m) {
      final total = (m['total'] as num?)?.toInt() ?? 0;
      final integ = (m['integrated'] as num?)?.toInt() ?? 0;
      final rate = total == 0
          ? '0%'
          : '${(integ / total * 100).toStringAsFixed(1)}%';
      return [(m['month'] as String?) ?? '', '$total', '$integ', rate];
    }).toList();
  }

  Future<void> _loadLeaders() async {
    final resp = await _dio.get('/users/leaders');
    final leaders = ((resp.data as Map<String, dynamic>)['leaders'] as List)
        .cast<Map<String, dynamic>>();
    _subtitle = 'Líderes cadastrados e ativos no sistema';
    _columns = ['Nome', 'E-mail', 'Telefone'];
    _rows = leaders
        .map(
          (l) => [
            (l['name'] as String?) ?? '—',
            (l['email'] as String?) ?? '—',
            (l['phone'] as String?) ?? '—',
          ],
        )
        .toList();
  }

  Future<void> _loadVisitorsMonth() async {
    final resp = await _dio.get('/visitors');
    final data = ((resp.data as Map<String, dynamic>)['data'] as List)
        .cast<Map<String, dynamic>>();
    final now = DateTime.now();
    final monthVisitors =
        data.where((v) {
          final created = DateTime.tryParse((v['createdAt'] as String?) ?? '');
          return created != null &&
              created.year == now.year &&
              created.month == now.month;
        }).toList()..sort(
          (a, b) => ((b['createdAt'] as String?) ?? '').compareTo(
            (a['createdAt'] as String?) ?? '',
          ),
        );
    _subtitle = 'Visitantes cadastrados no mês atual';
    _columns = ['Nome', 'Telefone', 'Célula', 'Status', 'Cadastro'];
    _rows = monthVisitors.map(_visitorRow).toList();
  }

  Future<void> _loadVisitorsByStatus({
    Set<String>? statuses,
    required String subtitle,
  }) async {
    final resp = await _dio.get('/visitors');
    final data = ((resp.data as Map<String, dynamic>)['data'] as List)
        .cast<Map<String, dynamic>>();
    final visitors =
        data.where((v) {
          if (statuses == null) return true;
          return statuses.contains((v['status'] as String?) ?? 'novo');
        }).toList()..sort(
          (a, b) => ((b['createdAt'] as String?) ?? '').compareTo(
            (a['createdAt'] as String?) ?? '',
          ),
        );
    _subtitle = subtitle;
    _columns = ['Nome', 'Telefone', 'Célula', 'Status', 'Cadastro'];
    _rows = visitors.map(_visitorRow).toList();
  }

  static List<String> _visitorRow(Map<String, dynamic> v) {
    final created = DateTime.tryParse((v['createdAt'] as String?) ?? '');
    final date = created == null
        ? '—'
        : '${created.day.toString().padLeft(2, '0')}/'
              '${created.month.toString().padLeft(2, '0')}/${created.year}';
    return [
      (v['name'] as String?) ?? '—',
      (v['phone'] as String?) ?? '—',
      (v['cellName'] as String?) ?? 'Sem célula',
      _statusLabel((v['status'] as String?) ?? 'novo'),
      date,
    ];
  }

  Future<void> _loadAttendanceByCell() async {
    final resp = await _dio.get('/dashboard/attendance-by-cell');
    final cells = ((resp.data as Map<String, dynamic>)['cells'] as List)
        .cast<Map<String, dynamic>>();
    _subtitle = 'Frequência média por célula (todas as reuniões)';
    _columns = ['Célula', 'Líder', 'Reuniões', 'Presenças', 'Frequência'];
    _rows = cells.map((c) {
      final total = (c['total'] as num?)?.toInt() ?? 0;
      final present = (c['present'] as num?)?.toInt() ?? 0;
      final rate = (c['rate'] as num?)?.toDouble() ?? 0;
      return [
        (c['cellName'] as String?) ?? '—',
        (c['leaderName'] as String?) ?? '—',
        '${(c['meetings'] as num?)?.toInt() ?? 0}',
        '$present/$total',
        '${rate.toStringAsFixed(1)}%',
      ];
    }).toList();
  }

  static String _statusLabel(String status) => switch (status) {
    'novo' => 'Novo',
    'em_acompanhamento' => 'Em acompanhamento',
    'integrado' => 'Integrado',
    'inativo' => 'Não retornou',
    _ => status,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.metric.title),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loading ? null : _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.error,
                    ),
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
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
                children: [
                  // ── Header da métrica clicada ─────────────────────────
                  AppCard(
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                          ),
                          child: Icon(
                            widget.metric.icon,
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
                                widget.metric.title,
                                style: AppTypography.bodySmall.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                widget.headerValue,
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
                    _subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // ── Grid de dados ─────────────────────────────────────
                  if (_rows.isEmpty)
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
                            columns: _columns
                                .map((c) => DataColumn(label: Text(c)))
                                .toList(),
                            rows: _rows
                                .map(
                                  (r) => DataRow(
                                    cells: r
                                        .map((v) => DataCell(Text(v)))
                                        .toList(),
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${_rows.length} registro(s)',
                    style: AppTypography.labelSmall.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
    );
  }
}
