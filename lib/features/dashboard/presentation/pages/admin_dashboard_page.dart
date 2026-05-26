import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/network/auth_storage.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';

void _showTopSnackBar(
  BuildContext context,
  String message, {
  Color backgroundColor = AppColors.error,
}) {
  final rootContext = Navigator.of(context, rootNavigator: true).context;
  final messenger = ScaffoldMessenger.maybeOf(rootContext);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
}

class _LeaderOption {
  const _LeaderOption({
    required this.id,
    required this.name,
    required this.email,
  });

  final String id;
  final String name;
  final String email;
}

/// Admin Dashboard — RF12
/// Multi-tab interface: Dashboard, Visitantes, Células, Relatórios
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedIndex = 0;

  static const _tabTitles = [
    'Dashboard',
    'Visitantes',
    'Células',
    'Relatórios',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _tabTitles[_selectedIndex],
              style: AppTypography.titleLarge.copyWith(color: AppColors.white),
            ),
            if (_selectedIndex == 0)
              Text(
                'Visão geral da integração',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.white.withValues(alpha: 0.75),
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _DashboardTab(onSwitchTab: (i) => setState(() => _selectedIndex = i)),
          const _VisitorsAdminTab(),
          const _CellsAdminTab(),
          const _ReportsTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Visitantes',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_2_outlined),
            selectedIcon: Icon(Icons.groups_2),
            label: 'Células',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Relatórios',
          ),
        ],
      ),
    );
  }
}

// ── Tab 0: Dashboard overview ────────────────────────────────────────────────

class _DashboardTab extends StatefulWidget {
  const _DashboardTab({required this.onSwitchTab});

  final void Function(int) onSwitchTab;

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  late final Dio _dio;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _months = [];
  List<Map<String, dynamic>> _cells = [];

  @override
  void initState() {
    super.initState();
    _dio = DioClient(AuthStorage()).dio;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _dio.get('/dashboard/stats'),
        _dio.get('/dashboard/monthly-stats'),
        _dio.get('/cells'),
      ]);
      if (!mounted) return;
      setState(() {
        _stats =
            (results[0].data as Map<String, dynamic>)['stats']
                as Map<String, dynamic>;
        _months = ((results[1].data as Map<String, dynamic>)['months'] as List)
            .cast<Map<String, dynamic>>();
        _cells = ((results[2].data as Map<String, dynamic>)['cells'] as List)
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar dashboard';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
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
          // ── Stat Cards ─────────────────────────────────────────
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

          // ── Integration Growth Chart ────────────────────────────
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
                : _IntegrationLineChart(months: _months),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Active Cells ───────────────────────────────────────
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
                          _CellRow(
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

          // ── Quick Actions ──────────────────────────────────────
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
                    _NewCellSheet(dio: DioClient(AuthStorage()).dio),
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
                    _NewLeaderSheet(dio: DioClient(AuthStorage()).dio),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppSpacing.sm),
                ),
                child: const Icon(
                  Icons.folder_outlined,
                  color: AppColors.primary,
                ),
              ),
              title: const Text('Gerenciar Materiais'),
              subtitle: const Text('Enviar e organizar materiais para líderes'),
              trailing: const Icon(
                Icons.chevron_right,
                color: AppColors.grey400,
              ),
              onTap: () => context.push('/admin/materials'),
            ),
          ),

          const SizedBox(height: AppSpacing.xl2),
        ],
      ),
    );
  }

  String _dayLabel(String dayOfWeek) {
    return switch (dayOfWeek) {
      'segunda' => 'Segunda-feira',
      'terca' => 'Terça-feira',
      'quarta' => 'Quarta-feira',
      'quinta' => 'Quinta-feira',
      'sexta' => 'Sexta-feira',
      'sabado' => 'Sábado',
      'domingo' => 'Domingo',
      _ => 'Dia não informado',
    };
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
}

// ── Tab 1: Visitors Admin ────────────────────────────────────────────────────

/// Line chart that renders total visitors (blue) vs integrated (green) by month.
class _IntegrationLineChart extends StatelessWidget {
  const _IntegrationLineChart({required this.months});

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

/// Bar chart for monthly new visitors (reports tab).
class _MonthlyBarChart extends StatelessWidget {
  const _MonthlyBarChart({required this.months});

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

class _VisitorsAdminTab extends StatefulWidget {
  const _VisitorsAdminTab();

  @override
  State<_VisitorsAdminTab> createState() => _VisitorsAdminTabState();
}

class _VisitorsAdminTabState extends State<_VisitorsAdminTab> {
  late final Dio _dio;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _visitors = [];
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _dio = DioClient(AuthStorage()).dio;
    _loadVisitors();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVisitors() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final resp = await _dio.get('/visitors');
      final data = (resp.data as Map<String, dynamic>)['data'] as List;
      if (!mounted) return;
      setState(() {
        _visitors = data.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar visitantes';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _visitors;
    return _visitors
        .where((v) => (v['name'] as String).toLowerCase().contains(q))
        .toList();
  }

  void _openNewVisitorSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NewVisitorSheet(dio: _dio),
    );
    if (created == true) _loadVisitors();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _isLoading
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
                      onPressed: _loadVisitors,
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadVisitors,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePaddingH,
                    AppSpacing.pagePaddingH,
                    AppSpacing.pagePaddingH,
                    88,
                  ),
                  children: [
                    AppSearchField(
                      hint: 'Pesquisar visitante...',
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: AppSpacing.base),
                    AppSectionHeader(
                      title: 'Todos os Visitantes (${_visitors.length})',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xl2),
                        child: Center(
                          child: Text(
                            'Nenhum visitante encontrado',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._filtered.map(
                        (v) => _VisitorAdminTile(
                          name: v['name'] as String,
                          status: v['status'] as String? ?? 'novo',
                          time: _relativeTime(v['createdAt'] as String),
                          onTap: () => _openVisitorDetails(v['id'] as String),
                        ),
                      ),
                  ],
                ),
              ),
        Positioned(
          bottom: AppSpacing.xl,
          right: AppSpacing.pagePaddingH,
          child: FloatingActionButton.extended(
            onPressed: _openNewVisitorSheet,
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Novo Visitante'),
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
          ),
        ),
      ],
    );
  }

  String _relativeTime(String isoDate) {
    final diff = DateTime.now().difference(DateTime.parse(isoDate));
    if (diff.inDays == 0) return 'hoje';
    if (diff.inDays == 1) return 'há 1 dia';
    if (diff.inDays < 7) return 'há ${diff.inDays} dias';
    if (diff.inDays < 14) return 'há 1 sem.';
    return 'há ${(diff.inDays / 7).round()} sem.';
  }

  Future<void> _openVisitorDetails(String visitorId) async {
    try {
      final resp = await _dio.get('/visitors/$visitorId');
      final visitor =
          (resp.data as Map<String, dynamic>)['visitor']
              as Map<String, dynamic>;
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _VisitorDetailsSheet(visitor: visitor),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      _showTopSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao abrir visitante',
      );
    }
  }
}

class _VisitorAdminTile extends StatelessWidget {
  const _VisitorAdminTile({
    required this.name,
    required this.status,
    required this.time,
    required this.onTap,
  });

  final String name;
  final String status;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      child: Row(
        children: [
          AppAvatar(initials: name.split(' ').map((e) => e[0]).take(2).join()),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.titleSmall),
                const SizedBox(height: AppSpacing.xs2),
                Row(
                  children: [
                    VisitorStatusBadge(status: status),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      time,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.grey400),
        ],
      ),
    );
  }
}

class _VisitorDetailsSheet extends StatelessWidget {
  const _VisitorDetailsSheet({required this.visitor});

  final Map<String, dynamic> visitor;

  @override
  Widget build(BuildContext context) {
    String textOrDash(Object? v) {
      final value = (v ?? '').toString().trim();
      return value.isEmpty ? 'Nao informado' : value;
    }

    final name = textOrDash(visitor['name']);
    final status = textOrDash(visitor['status']);
    final createdAt = DateTime.tryParse(
      (visitor['createdAt'] as String?) ?? '',
    );

    String relativeTime() {
      if (createdAt == null) return 'Sem data';
      final diff = DateTime.now().difference(createdAt);
      if (diff.inDays == 0) return 'hoje';
      if (diff.inDays == 1) return 'ha 1 dia';
      if (diff.inDays < 7) return 'ha ${diff.inDays} dias';
      if (diff.inDays < 14) return 'ha 1 sem.';
      return 'ha ${(diff.inDays / 7).round()} sem.';
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => SingleChildScrollView(
        controller: controller,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  AppAvatar(
                    initials: name.split(' ').map((e) => e[0]).take(2).join(),
                    size: 56,
                  ),
                  const SizedBox(width: AppSpacing.base),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: AppTypography.headlineSmall),
                        const SizedBox(height: AppSpacing.xs),
                        VisitorStatusBadge(status: status),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.phone_outlined,
                      label: 'Telefone',
                      value: textOrDash(visitor['phone']),
                    ),
                    const Divider(height: 1),
                    _DetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Endereco',
                      value: textOrDash(visitor['address']),
                    ),
                    const Divider(height: 1),
                    _DetailRow(
                      icon: Icons.access_time_outlined,
                      label: 'Cadastrado',
                      value: relativeTime(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Alterar status', style: AppTypography.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: const [
                  _VisitorStatusChip(label: 'Novo'),
                  _VisitorStatusChip(label: 'Em acompanhamento'),
                  _VisitorStatusChip(label: 'Integrado'),
                  _VisitorStatusChip(label: 'Inativo'),
                ],
              ),
              const SizedBox(height: AppSpacing.base),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary, size: 20),
      title: Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: AppColors.textSecondary,
        ),
      ),
      subtitle: Text(value, style: AppTypography.titleSmall),
    );
  }
}

class _VisitorStatusChip extends StatelessWidget {
  const _VisitorStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label, style: AppTypography.labelMedium),
      onPressed: () {
        _showTopSnackBar(
          context,
          'Status alterado para: $label',
          backgroundColor: AppColors.success,
        );
      },
    );
  }
}

// ── Tab 2: Cells Admin ───────────────────────────────────────────────────────

class _CellsAdminTab extends StatefulWidget {
  const _CellsAdminTab();

  @override
  State<_CellsAdminTab> createState() => _CellsAdminTabState();
}

class _CellsAdminTabState extends State<_CellsAdminTab> {
  late final Dio _dio;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _cells = [];
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _dio = DioClient(AuthStorage()).dio;
    _loadCells();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCells() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final resp = await _dio.get('/cells');
      final data = (resp.data as Map<String, dynamic>)['cells'] as List;
      if (!mounted) return;
      setState(() {
        _cells = data.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar células';
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _cells;
    return _cells
        .where((c) => (c['name'] as String).toLowerCase().contains(q))
        .toList();
  }

  static const _dayLabels = {
    'segunda': 'Segunda-feira',
    'terca': 'Terça-feira',
    'quarta': 'Quarta-feira',
    'quinta': 'Quinta-feira',
    'sexta': 'Sexta-feira',
    'sabado': 'Sábado',
    'domingo': 'Domingo',
  };

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _isLoading
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
                      onPressed: _loadCells,
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _loadCells,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePaddingH,
                    AppSpacing.pagePaddingH,
                    AppSpacing.pagePaddingH,
                    88,
                  ),
                  children: [
                    AppSearchField(
                      hint: 'Pesquisar célula...',
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: AppSpacing.base),
                    AppSectionHeader(
                      title: 'Células Cadastradas (${_cells.length})',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    if (_filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xl2),
                        child: Center(
                          child: Text(
                            'Nenhuma célula encontrada',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      )
                    else
                      ..._filtered.map((c) {
                        final id = c['id'] as String;
                        final name = c['name'] as String;
                        final leader = c['leaderName'] as String? ?? '—';
                        final day =
                            _dayLabels[c['dayOfWeek'] as String] ??
                            c['dayOfWeek'] as String;
                        final members =
                            '${c['currentCount']}/${c['maxCapacity']}';
                        final address =
                            (c['address'] as String?) ?? 'Não informado';
                        return _CellAdminCard(
                          id: id,
                          name: name,
                          leader: leader,
                          day: day,
                          members: members,
                          address: address,
                          onTap: () async {
                            final changed = await Navigator.of(context)
                                .push<bool>(
                                  MaterialPageRoute<bool>(
                                    builder: (_) => _CellDetailsPage(
                                      id: id,
                                      name: name,
                                      leader: leader,
                                      day: day,
                                      members: members,
                                      address: address,
                                    ),
                                  ),
                                );
                            if (changed == true) _loadCells();
                          },
                        );
                      }),
                  ],
                ),
              ),
        Positioned(
          bottom: AppSpacing.xl,
          right: AppSpacing.pagePaddingH,
          child: FloatingActionButton.extended(
            onPressed: () async {
              final created = await showModalBottomSheet<bool>(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) => _NewCellSheet(dio: _dio),
              );
              if (created == true) _loadCells();
            },
            icon: const Icon(Icons.add),
            label: const Text('Nova Célula'),
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
          ),
        ),
      ],
    );
  }
}

class _CellAdminCard extends StatelessWidget {
  const _CellAdminCard({
    required this.id,
    required this.name,
    required this.leader,
    required this.day,
    required this.members,
    required this.address,
    required this.onTap,
  });

  final String id;
  final String name;
  final String leader;
  final String day;
  final String members;
  final String address;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: const Icon(
              Icons.groups_2_outlined,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTypography.titleSmall),
                Text(
                  '$leader · $day',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const AppBadge(
                label: 'Ativa',
                variant: AppBadgeVariant.success,
                size: AppBadgeSize.sm,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                members,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Tab 3: Reports ───────────────────────────────────────────────────────────

class _ReportsTab extends StatefulWidget {
  const _ReportsTab();

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  late final Dio _dio;
  bool _loading = true;
  String? _error;
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _months = [];

  @override
  void initState() {
    super.initState();
    _dio = DioClient(AuthStorage()).dio;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _dio.get('/dashboard/stats'),
        _dio.get('/dashboard/monthly-stats'),
      ]);
      if (!mounted) return;
      setState(() {
        _stats =
            (results[0].data as Map<String, dynamic>)['stats']
                as Map<String, dynamic>;
        _months = ((results[1].data as Map<String, dynamic>)['months'] as List)
            .cast<Map<String, dynamic>>();
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar relatórios';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
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

    final totalVisitors = _stats['totalVisitors'] as int? ?? 0;
    final integrated = _stats['integratedVisitors'] as int? ?? 0;
    final leaders = _stats['totalLeaders'] as int? ?? 0;
    final newThisMonth = _stats['newVisitorsThisMonth'] as int? ?? 0;
    final avgAttendance = _stats['averageAttendanceRate'] as num? ?? 0;
    final integrationRate = totalVisitors == 0
        ? '0%'
        : '${(integrated / totalVisitors * 100).toStringAsFixed(1)}%';

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        children: [
          const SizedBox(height: AppSpacing.base),
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
                label: 'Taxa de Integração',
                value: integrationRate,
                icon: Icons.trending_up,
                color: AppColors.success,
              ),
              StatCard(
                label: 'Líderes Ativos',
                value: '$leaders',
                icon: Icons.people,
                color: AppColors.primary,
              ),
              StatCard(
                label: 'Visitantes (mês)',
                value: '$newThisMonth',
                icon: Icons.calendar_month_outlined,
                color: AppColors.accent,
              ),
              StatCard(
                label: 'Média Frequência',
                value: '${avgAttendance.toStringAsFixed(1)}%',
                icon: Icons.bar_chart,
                color: AppColors.secondary,
              ),
            ]),
          ),

          const SizedBox(height: AppSpacing.xl),

          AppSectionHeader(title: 'Visitantes por Mês (últ. 6 meses)'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: _months.isEmpty
                ? SizedBox(
                    height: 200,
                    child: Center(
                      child: Text(
                        'Sem dados de visitantes ainda.',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MonthlyBarChart(months: _months),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          _ChartLegend(
                            color: AppColors.primary,
                            label: 'Total',
                          ),
                          const SizedBox(width: AppSpacing.base),
                          _ChartLegend(
                            color: AppColors.success,
                            label: 'Integrados',
                          ),
                        ],
                      ),
                    ],
                  ),
          ),

          const SizedBox(height: AppSpacing.xl),

          AppSectionHeader(title: 'Exportar Relatório'),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Exportar em PDF',
            variant: AppButtonVariant.outline,
            prefixIcon: Icons.picture_as_pdf_outlined,
            onPressed: () {},
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Exportar em Excel',
            variant: AppButtonVariant.outline,
            prefixIcon: Icons.table_chart_outlined,
            onPressed: () {},
          ),

          const SizedBox(height: AppSpacing.xl2),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _CellDetailsPage extends StatefulWidget {
  const _CellDetailsPage({
    required this.id,
    required this.name,
    required this.leader,
    required this.day,
    required this.members,
    required this.address,
  });

  final String id;
  final String name;
  final String leader;
  final String day;
  final String members;
  final String address;

  @override
  State<_CellDetailsPage> createState() => _CellDetailsPageState();
}

class _CellDetailsPageState extends State<_CellDetailsPage> {
  late final Dio _dio;
  bool _loading = true;
  bool _isActive = true;
  String? _error;
  Map<String, dynamic>? _cell;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _dio = DioClient(AuthStorage()).dio;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _dio.get('/cells/${widget.id}'),
        _dio.get('/cells/${widget.id}/members'),
      ]);
      final cell =
          (results[0].data as Map<String, dynamic>)['cell']
              as Map<String, dynamic>;
      final members =
          (results[1].data as Map<String, dynamic>)['members'] as List;

      if (!mounted) return;
      setState(() {
        _cell = cell;
        _members = members.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar detalhes da célula';
        _loading = false;
      });
    }
  }

  Future<void> _addMember() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddCellMemberSheet(dio: _dio, cellId: widget.id),
    );
    if (created == true) _load();
  }

  Future<void> _editCell() async {
    final cell = _cell;
    if (cell == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditCellSheet(dio: _dio, cell: cell),
    );
    if (changed == true) {
      await _load();
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _deleteCell() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir célula'),
        content: const Text(
          'Confirma exclusão da célula? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Excluir', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _dio.delete('/cells/${widget.id}');
      if (!mounted) return;
      _showTopSnackBar(
        context,
        'Célula excluída com sucesso',
        backgroundColor: AppColors.success,
      );
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      _showTopSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao excluir célula',
      );
    }
  }

  void _toggleActive() {
    setState(() => _isActive = !_isActive);
    _showTopSnackBar(
      context,
      _isActive ? 'Célula ativada' : 'Célula desativada',
      backgroundColor: AppColors.success,
    );
  }

  Future<void> _openAddressMap(String address) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddressMapSheet(
        title: (_cell?['name'] as String?) ?? widget.name,
        address: address,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detalhes da Célula'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Detalhes da Célula'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
        ),
        body: Center(
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
                onPressed: _load,
              ),
            ],
          ),
        ),
      );
    }

    final cell = _cell ?? const <String, dynamic>{};
    final name = (cell['name'] as String?) ?? widget.name;
    final leader = (cell['leaderName'] as String?) ?? widget.leader;
    final day = (cell['dayOfWeek'] as String?) ?? widget.day;
    final time = (cell['time'] as String?) ?? '';
    final address = (cell['address'] as String?) ?? widget.address;
    final membersLabel = '${_members.length}/${(cell['maxCapacity'] ?? '—')}';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da Célula'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        actions: [
          IconButton(
            tooltip: 'Editar',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _editCell,
          ),
          IconButton(
            tooltip: 'Excluir',
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleteCell,
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(name, style: AppTypography.headlineSmall),
                    ),
                    AppBadge(
                      label: _isActive ? 'Ativa' : 'Inativa',
                      variant: _isActive
                          ? AppBadgeVariant.success
                          : AppBadgeVariant.warning,
                      size: AppBadgeSize.sm,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.base),
                Text('ID: ${widget.id}', style: AppTypography.bodySmall),
                const SizedBox(height: AppSpacing.xs),
                Text('Líder: $leader', style: AppTypography.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Dia: $day ${time.isEmpty ? '' : '· $time'}',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Participantes: $membersLabel',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                InkWell(
                  onTap: () => _openAddressMap(address),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          address,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: _isActive ? 'Desativar' : 'Ativar',
                        variant: AppButtonVariant.outline,
                        prefixIcon: _isActive
                            ? Icons.toggle_off_outlined
                            : Icons.toggle_on_outlined,
                        onPressed: _toggleActive,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: AppButton(
                        label: 'Adicionar Membro',
                        prefixIcon: Icons.person_add_outlined,
                        onPressed: _addMember,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          AppSectionHeader(title: 'Membros da Célula (${_members.length})'),
          const SizedBox(height: AppSpacing.sm),
          if (_members.isEmpty)
            AppCard(
              child: Text(
                'Nenhum membro nesta célula.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ..._members.map(
              (m) => AppCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    AppAvatar(
                      initials: ((m['name'] as String?) ?? 'M')
                          .split(' ')
                          .where((e) => e.isNotEmpty)
                          .map((e) => e[0])
                          .take(2)
                          .join(),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (m['name'] as String?) ?? 'Sem nome',
                            style: AppTypography.titleSmall,
                          ),
                          const SizedBox(height: AppSpacing.xs2),
                          Text(
                            (m['phone'] as String?) ?? 'Sem telefone',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AppBadge(
                      label: 'Membro',
                      variant: AppBadgeVariant.success,
                      size: AppBadgeSize.sm,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddCellMemberSheet extends StatefulWidget {
  const _AddCellMemberSheet({required this.dio, required this.cellId});

  final Dio dio;
  final String cellId;

  @override
  State<_AddCellMemberSheet> createState() => _AddCellMemberSheetState();
}

class _AddCellMemberSheetState extends State<_AddCellMemberSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      _showTopSnackBar(
        context,
        'Informe nome e telefone',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.dio.post(
        '/cells/${widget.cellId}/members',
        data: {'name': name, 'phone': phone},
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showTopSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao adicionar membro',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Adicionar membro', style: AppTypography.headlineSmall),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _nameCtrl,
                label: 'Nome *',
                hint: 'Nome do membro',
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _phoneCtrl,
                label: 'Telefone *',
                hint: '(11) 99999-9999',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.base),
              AppButton(
                label: _saving ? 'Salvando...' : 'Adicionar',
                prefixIcon: Icons.person_add_alt_1_outlined,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditCellSheet extends StatefulWidget {
  const _EditCellSheet({required this.dio, required this.cell});

  final Dio dio;
  final Map<String, dynamic> cell;

  @override
  State<_EditCellSheet> createState() => _EditCellSheetState();
}

class _EditCellSheetState extends State<_EditCellSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _neighborhoodCtrl;
  late final TextEditingController _cityCtrl;
  late final TextEditingController _timeCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: (widget.cell['name'] as String?) ?? '',
    );
    _addressCtrl = TextEditingController(
      text: (widget.cell['address'] as String?) ?? '',
    );
    _neighborhoodCtrl = TextEditingController(
      text: (widget.cell['neighborhood'] as String?) ?? '',
    );
    _cityCtrl = TextEditingController(
      text: (widget.cell['city'] as String?) ?? '',
    );
    _timeCtrl = TextEditingController(
      text: (widget.cell['time'] as String?) ?? '19:00',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _cityCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.dio.patch(
        '/cells/${widget.cell['id']}',
        data: {
          'name': _nameCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          'neighborhood': _neighborhoodCtrl.text.trim(),
          'city': _cityCtrl.text.trim(),
          'time': _timeCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showTopSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao salvar célula',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Editar célula', style: AppTypography.headlineSmall),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _nameCtrl,
                label: 'Nome',
                hint: 'Nome da célula',
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _addressCtrl,
                label: 'Endereço',
                hint: 'Rua, número',
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _neighborhoodCtrl,
                label: 'Bairro',
                hint: 'Bairro',
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _cityCtrl,
                label: 'Cidade',
                hint: 'Cidade',
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _timeCtrl,
                label: 'Horário',
                hint: '19:00',
              ),
              const SizedBox(height: AppSpacing.base),
              AppButton(
                label: _saving ? 'Salvando...' : 'Salvar alterações',
                prefixIcon: Icons.save_outlined,
                onPressed: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddressMapSheet extends StatefulWidget {
  const _AddressMapSheet({required this.title, required this.address});

  final String title;
  final String address;

  @override
  State<_AddressMapSheet> createState() => _AddressMapSheetState();
}

class _AddressMapSheetState extends State<_AddressMapSheet> {
  LatLng? _position;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _geocode();
  }

  Future<void> _geocode() async {
    try {
      final locations = await locationFromAddress(widget.address);
      if (!mounted) return;
      if (locations.isNotEmpty) {
        setState(() {
          _position = LatLng(
            locations.first.latitude,
            locations.first.longitude,
          );
          _loading = false;
        });
      } else {
        setState(() {
          _error = 'Endereço não encontrado';
          _loading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _position = const LatLng(-23.5505, -46.6333);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppColors.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.title, style: AppTypography.titleSmall),
                      Text(
                        widget.address,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : FlutterMap(
                    options: MapOptions(
                      initialCenter: _position!,
                      initialZoom: 15,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.sistemaigreja.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _position!,
                            width: 40,
                            height: 40,
                            child: const Icon(
                              Icons.location_pin,
                              color: AppColors.primary,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Shared bottom sheets ─────────────────────────────────────────────────────

class _NewCellSheet extends StatefulWidget {
  const _NewCellSheet({required this.dio});
  final Dio dio;

  @override
  State<_NewCellSheet> createState() => _NewCellSheetState();
}

class _NewCellSheetState extends State<_NewCellSheet> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _timeCtrl = TextEditingController(text: '19:00');
  String _dayOfWeek = 'terca';
  bool _isSaving = false;
  bool _isLoadingLeaders = true;
  List<_LeaderOption> _leaders = const [];
  _LeaderOption? _selectedLeader;

  static const _days = [
    ('segunda', 'Segunda-feira'),
    ('terca', 'Terça-feira'),
    ('quarta', 'Quarta-feira'),
    ('quinta', 'Quinta-feira'),
    ('sexta', 'Sexta-feira'),
    ('sabado', 'Sábado'),
    ('domingo', 'Domingo'),
  ];

  @override
  void initState() {
    super.initState();
    _loadLeaders();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _cityCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLeaders() async {
    setState(() => _isLoadingLeaders = true);
    try {
      final resp = await widget.dio.get('/users/leaders');
      final data = (resp.data as Map<String, dynamic>)['leaders'] as List;
      final leaders = data
          .map(
            (u) => _LeaderOption(
              id: u['id'] as String,
              name: u['name'] as String,
              email: (u['email'] as String?) ?? '',
            ),
          )
          .toList();

      if (!mounted) return;
      setState(() {
        _leaders = leaders;
        _selectedLeader = leaders.isNotEmpty ? leaders.first : null;
        _isLoadingLeaders = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingLeaders = false);
      _showTopSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar lideres',
      );
    }
  }

  Future<void> _openLeaderSelector() async {
    if (_leaders.isEmpty) {
      _showTopSnackBar(
        context,
        'Nenhum lider cadastrado. Cadastre um lider antes de criar a celula.',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    final selected = await Navigator.of(context).push<_LeaderOption>(
      MaterialPageRoute(
        builder: (_) => _LeaderSelectorPage(
          leaders: _leaders,
          initialId: _selectedLeader?.id,
        ),
      ),
    );

    if (selected != null && mounted) {
      setState(() => _selectedLeader = selected);
    }
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final neighborhood = _neighborhoodCtrl.text.trim();
    final city = _cityCtrl.text.trim();
    final time = _timeCtrl.text.trim();
    final leaderId = _selectedLeader?.id ?? '';

    if (name.isEmpty ||
        address.isEmpty ||
        city.isEmpty ||
        time.isEmpty ||
        leaderId.isEmpty) {
      _showTopSnackBar(
        context,
        'Preencha todos os campos obrigatorios',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.dio.post(
        '/cells',
        data: {
          'name': name,
          'leaderId': leaderId,
          'address': address,
          'neighborhood': neighborhood.isEmpty ? city : neighborhood,
          'city': city,
          'dayOfWeek': _dayOfWeek,
          'time': time,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showTopSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao criar celula',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              Text('Nova Célula', style: AppTypography.headlineSmall),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                controller: _nameCtrl,
                label: 'Nome da Célula *',
                hint: 'Ex: Célula Esperança',
                prefixIcon: Icons.groups_2_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              InkWell(
                onTap: _isLoadingLeaders ? null : _openLeaderSelector,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Lider *',
                    prefixIcon: const Icon(Icons.person_search_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  child: _isLoadingLeaders
                      ? const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Text('Carregando lideres...'),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedLeader?.name ?? 'Selecionar lider',
                                style: AppTypography.bodyMedium,
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _addressCtrl,
                label: 'Endereço *',
                hint: 'Rua, número',
                prefixIcon: Icons.location_on_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _neighborhoodCtrl,
                label: 'Bairro',
                hint: 'Bairro',
                prefixIcon: Icons.map_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _cityCtrl,
                label: 'Cidade *',
                hint: 'São Paulo',
                prefixIcon: Icons.location_city_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _timeCtrl,
                label: 'Horário *',
                hint: '19:00',
                prefixIcon: Icons.access_time_outlined,
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.datetime,
              ),
              const SizedBox(height: AppSpacing.base),
              Text(
                'Dia da semana',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.grey700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String>(
                initialValue: _dayOfWeek,
                items: _days
                    .map(
                      (d) => DropdownMenuItem(value: d.$1, child: Text(d.$2)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _dayOfWeek = v!),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: const BorderSide(color: AppColors.grey300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base,
                    vertical: AppSpacing.md,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: _isSaving ? 'Salvando...' : 'Criar Célula',
                prefixIcon: Icons.add,
                onPressed: _isSaving ? null : _save,
              ),
              const SizedBox(height: AppSpacing.base),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderSelectorPage extends StatefulWidget {
  const _LeaderSelectorPage({required this.leaders, required this.initialId});

  final List<_LeaderOption> leaders;
  final String? initialId;

  @override
  State<_LeaderSelectorPage> createState() => _LeaderSelectorPageState();
}

class _LeaderSelectorPageState extends State<_LeaderSelectorPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.leaders.where((l) {
      final q = _query.toLowerCase();
      return l.name.toLowerCase().contains(q) ||
          l.email.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecionar lider'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        child: Column(
          children: [
            AppSearchField(
              hint: 'Pesquisar lider...',
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: AppSpacing.base),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final leader = filtered[index];
                  final isSelected = leader.id == widget.initialId;
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    onTap: () => Navigator.of(context).pop(leader),
                    child: Row(
                      children: [
                        AppAvatar(
                          initials: leader.name
                              .split(' ')
                              .map((e) => e[0])
                              .take(2)
                              .join(),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                leader.name,
                                style: AppTypography.titleSmall,
                              ),
                              const SizedBox(height: AppSpacing.xs2),
                              Text(
                                leader.email,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── New Visitor Sheet ────────────────────────────────────────────────────────

class _NewVisitorSheet extends StatefulWidget {
  const _NewVisitorSheet({required this.dio});
  final Dio dio;

  @override
  State<_NewVisitorSheet> createState() => _NewVisitorSheetState();
}

class _NewVisitorSheetState extends State<_NewVisitorSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      _showTopSnackBar(
        context,
        'Nome e telefone sao obrigatorios',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.dio.post(
        '/visitors',
        data: {
          'name': name,
          'phone': phone,
          if (_emailCtrl.text.trim().isNotEmpty)
            'email': _emailCtrl.text.trim(),
          if (_addressCtrl.text.trim().isNotEmpty)
            'address': _addressCtrl.text.trim(),
          if (_neighborhoodCtrl.text.trim().isNotEmpty)
            'neighborhood': _neighborhoodCtrl.text.trim(),
          if (_cityCtrl.text.trim().isNotEmpty) 'city': _cityCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showTopSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao cadastrar visitante',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              Text('Novo Visitante', style: AppTypography.headlineSmall),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                controller: _nameCtrl,
                label: 'Nome *',
                hint: 'Nome completo',
                prefixIcon: Icons.person_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _phoneCtrl,
                label: 'Telefone *',
                hint: '(11) 99999-9999',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _emailCtrl,
                label: 'E-mail',
                hint: 'email@exemplo.com',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _addressCtrl,
                label: 'Endereço',
                hint: 'Rua, número',
                prefixIcon: Icons.location_on_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _neighborhoodCtrl,
                label: 'Bairro',
                hint: 'Bairro',
                prefixIcon: Icons.map_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _cityCtrl,
                label: 'Cidade',
                hint: 'São Paulo',
                prefixIcon: Icons.location_city_outlined,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: _isSaving ? 'Salvando...' : 'Cadastrar Visitante',
                prefixIcon: Icons.person_add_outlined,
                onPressed: _isSaving ? null : _save,
              ),
              const SizedBox(height: AppSpacing.base),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewLeaderSheet extends StatefulWidget {
  const _NewLeaderSheet({required this.dio});
  final Dio dio;

  @override
  State<_NewLeaderSheet> createState() => _NewLeaderSheetState();
}

class _NewLeaderSheetState extends State<_NewLeaderSheet> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || password.length < 6) {
      _showTopSnackBar(
        context,
        'Preencha nome, email e senha (minimo 6 caracteres)',
        backgroundColor: AppColors.warning,
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await widget.dio.post(
        '/auth/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'role': 'LIDER',
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
      _showTopSnackBar(
        context,
        'Lider cadastrado com sucesso',
        backgroundColor: AppColors.success,
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showTopSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao cadastrar lider',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              Text('Novo Líder', style: AppTypography.headlineSmall),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                controller: _nameCtrl,
                label: 'Nome completo',
                hint: 'Nome do líder',
                prefixIcon: Icons.person_outline,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _emailCtrl,
                label: 'E-mail',
                hint: 'lider@email.com',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _phoneCtrl,
                label: 'Telefone',
                hint: '(11) 99999-9999',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _passwordCtrl,
                label: 'Senha temporaria *',
                hint: 'Minimo 6 caracteres',
                prefixIcon: Icons.lock_outline,
                obscureText: true,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: _isSaving ? 'Salvando...' : 'Criar Líder',
                prefixIcon: Icons.person_add_outlined,
                onPressed: _isSaving ? null : _save,
              ),
              const SizedBox(height: AppSpacing.base),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared widget used in dashboard tab ──────────────────────────────────────

class _CellRow extends StatelessWidget {
  const _CellRow({
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
