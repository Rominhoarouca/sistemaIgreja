import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/auth_storage.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../data/services/dashboard_service.dart';
import '../../domain/exceptions/service_exception.dart';
import '../../domain/services/i_dashboard_service.dart';
import '../widgets/integration_line_chart.dart';
import 'chart_detail_page.dart';
import 'admin_dashboard_sheets.dart';

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

  @override
  void initState() {
    super.initState();
    _dashboardService = DashboardService(DioClient(AuthStorage()).dio);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _dashboardService.getStats(),
        _dashboardService.getMonthlyStats(),
        DioClient(AuthStorage()).dio.get('/cells'),
      ]);
      if (!mounted) return;
      setState(() {
        _stats = results[0] as Map<String, dynamic>;
        _months = results[1] as List<Map<String, dynamic>>;
        final resp = results[2] as Response<dynamic>;
        _cells = ((resp.data as Map<String, dynamic>)['cells'] as List)
            .cast<Map<String, dynamic>>();
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

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        children: [
          GridView.custom(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.sm,
              mainAxisSpacing: AppSpacing.sm,
              mainAxisExtent: 148,
            ),
            childrenDelegate: SliverChildListDelegate([
              StatCard(
                label: 'Visitantes Cadastrados',
                value: '$totalVisitors',
                icon: Icons.people_outline,
                color: AppColors.primary,
              ),
              StatCard(
                label: 'Encaminhamentos',
                value: '$forwarded',
                icon: Icons.send_outlined,
                color: AppColors.secondary,
              ),
              StatCard(
                label: 'Visitantes Integrados',
                value: '$integrated',
                icon: Icons.check_circle_outline,
                color: AppColors.success,
              ),
              StatCard(
                label: 'Frequência nas Células',
                value: '${avgAttendance.toStringAsFixed(1)}%',
                icon: Icons.bar_chart_outlined,
                color: AppColors.accent,
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.xl),
          AppSectionHeader(
            title: 'Crescimento de Integração',
            actionLabel: 'Ver relatório',
            onAction: () => widget.onSwitchTab(3),
          ),
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
                    NewCellSheet(dio: DioClient(AuthStorage()).dio),
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
                    NewLeaderSheet(dio: DioClient(AuthStorage()).dio),
                  ),
                ),
              ),
            ],
          ),
          ..._buildQuickActionTiles(context),
          const SizedBox(height: AppSpacing.xl2),
        ],
      ),
    );
  }

  List<Widget> _buildQuickActionTiles(BuildContext context) => [
    const SizedBox(height: AppSpacing.sm),
    _QuickActionTile(
      icon: Icons.folder_outlined,
      iconColor: AppColors.primary,
      title: 'Gerenciar Materiais',
      subtitle: 'Enviar e organizar materiais para líderes',
      onTap: () => context.push('/admin/materials'),
    ),
    const SizedBox(height: AppSpacing.sm),
    _QuickActionTile(
      icon: Icons.people_outlined,
      iconColor: AppColors.primary,
      title: 'Líderes',
      subtitle: 'Visualizar líderes, células e frequências',
      onTap: () => context.push(AppRoutes.adminLeaders),
    ),
    const SizedBox(height: AppSpacing.sm),
    _QuickActionTile(
      icon: Icons.manage_accounts_outlined,
      iconColor: AppColors.secondary,
      title: 'Supervisores',
      subtitle: 'Gerenciar supervisores e seus líderes',
      onTap: () => context.push(AppRoutes.adminSupervisors),
    ),
    const SizedBox(height: AppSpacing.sm),
    _QuickActionTile(
      icon: Icons.account_tree_outlined,
      iconColor: AppColors.accent,
      title: 'Coordenações',
      subtitle: 'Criar e gerenciar coordenações',
      onTap: () => context.push(AppRoutes.adminCoordenacoes),
    ),
    const SizedBox(height: AppSpacing.sm),
    _QuickActionTile(
      icon: Icons.location_city_outlined,
      iconColor: Colors.teal,
      title: 'Cidades e Bairros',
      subtitle: 'Gerenciar localidades',
      onTap: () => context.push(AppRoutes.adminLocation),
    ),
    const SizedBox(height: AppSpacing.sm),
    _QuickActionTile(
      icon: Icons.category_outlined,
      iconColor: Colors.deepPurple,
      title: 'Tipos de Célula',
      subtitle: 'Criar e gerenciar tipos de célula',
      onTap: () => context.push(AppRoutes.adminCellTypes),
    ),
    const SizedBox(height: AppSpacing.sm),
    _QuickActionTile(
      icon: Icons.chat_outlined,
      iconColor: Color(0xFF25D366),
      title: 'WhatsApp',
      subtitle: 'Enviar mensagens em lote ou individual',
      onTap: () => context.push(AppRoutes.adminWhatsapp),
    ),
    const SizedBox(height: AppSpacing.sm),
    _QuickActionTile(
      icon: Icons.person_add_outlined,
      iconColor: Colors.indigo,
      title: 'Novo Cadastro',
      subtitle: 'Líderes, Supervisores e Coordenadores',
      onTap: () => context.push(AppRoutes.adminUsersRegister),
    ),
  ];
}

// ── Private widgets ──────────────────────────────────────────────────────────

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppSpacing.sm),
          ),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, color: AppColors.grey400),
        onTap: onTap,
      ),
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
