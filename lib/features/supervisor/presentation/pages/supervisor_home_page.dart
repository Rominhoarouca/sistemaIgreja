import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/auth_storage.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';

/// Supervisor Panel — coordinates multiple leaders and their cells.
class SupervisorHomePage extends StatefulWidget {
  const SupervisorHomePage({super.key});

  @override
  State<SupervisorHomePage> createState() => _SupervisorHomePageState();
}

class _SupervisorHomePageState extends State<SupervisorHomePage> {
  int _selectedTab = 0;

  static const _tabs = [
    NavigationDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: 'Líderes',
    ),
    NavigationDestination(
      icon: Icon(Icons.dashboard_outlined),
      selectedIcon: Icon(Icons.dashboard),
      label: 'Visão Geral',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;

    final appBar = AppBar(
      title: const Text('Painel do Supervisor'),
      elevation: 0,
      backgroundColor: AppColors.background,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () => context.push('/notifications'),
        ),
        IconButton(
          icon: const Icon(Icons.account_circle_outlined),
          onPressed: () => context.push('/profile'),
        ),
        const SizedBox(width: AppSpacing.xs),
      ],
    );

    final tabContent = IndexedStack(
      index: _selectedTab,
      children: const [_LeadersTab(), _OverviewTab()],
    );

    if (isWide) {
      return Scaffold(
        appBar: appBar,
        backgroundColor: AppColors.background,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedTab,
              onDestinationSelected: (i) => setState(() => _selectedTab = i),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text('Líderes'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Visão Geral'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: tabContent),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      backgroundColor: AppColors.background,
      body: tabContent,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (i) => setState(() => _selectedTab = i),
        destinations: _tabs,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1 — LEADERS
// ═══════════════════════════════════════════════════════════════════════════

class _LeadersTab extends StatefulWidget {
  const _LeadersTab();

  @override
  State<_LeadersTab> createState() => _LeadersTabState();
}

class _LeadersTabState extends State<_LeadersTab> {
  late final Dio _dio;
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  String _query = '';
  List<_LeaderData> _leaders = [];

  @override
  void initState() {
    super.initState();
    _dio = DioClient(AuthStorage()).dio;
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // GET /users/my-leaders returns leaders assigned to this supervisor.
      // Falls back to all leaders if none assigned yet.
      final resp = await _dio.get('/users/my-leaders');
      final data = (resp.data as Map<String, dynamic>)['leaders'] as List;
      if (!mounted) return;

      // For each leader, fetch their cells
      final leaders = <_LeaderData>[];
      for (final item in data) {
        final userId = item['id'] as String;
        List<_CellSummary> cells = [];
        try {
          final cellResp = await _dio.get(
            '/cells',
            queryParameters: {'leaderId': userId},
          );
          final cellList =
              (cellResp.data as Map<String, dynamic>)['cells'] as List? ?? [];
          cells = cellList
              .map((c) => _CellSummary.fromJson(c as Map<String, dynamic>))
              .toList();
        } catch (_) {
          // fallback: try my-cell style
        }
        leaders.add(_LeaderData.fromJson(item as Map<String, dynamic>, cells));
      }
      setState(() {
        _leaders = leaders;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar líderes';
        _loading = false;
      });
    }
  }

  List<_LeaderData> get _filtered {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _leaders;
    return _leaders.where((l) => l.name.toLowerCase().contains(q)).toList();
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

    final filtered = _filtered;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        children: [
          AppSearchField(
            hint: 'Pesquisar líder...',
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: AppSpacing.base),
          AppSectionHeader(title: 'Líderes coordenados (${filtered.length})'),
          const SizedBox(height: AppSpacing.sm),
          if (filtered.isEmpty)
            AppEmptyState(
              title: 'Nenhum líder encontrado',
              subtitle: 'Solicite ao administrador que associe líderes a você.',
              icon: Icons.people_outline,
            )
          else
            ...filtered.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _LeaderCard(
                  leader: l,
                  onViewCells: () => _showCellsSheet(context, l),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showCellsSheet(BuildContext context, _LeaderData leader) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _LeaderCellsSheet(leader: leader, dio: _dio),
    );
  }
}

// ── Leader card ────────────────────────────────────────────────────────────

class _LeaderCard extends StatelessWidget {
  const _LeaderCard({required this.leader, required this.onViewCells});

  final _LeaderData leader;
  final VoidCallback onViewCells;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    Text(leader.name, style: AppTypography.titleSmall),
                    if (leader.email.isNotEmpty)
                      Text(
                        leader.email,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              AppButton(
                label: 'Células',
                variant: AppButtonVariant.ghost,
                size: AppButtonSize.sm,
                isFullWidth: false,
                suffixIcon: Icons.chevron_right,
                onPressed: onViewCells,
              ),
            ],
          ),
          if (leader.cells.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: leader.cells.map((c) {
                return Chip(
                  label: Text(c.name, style: AppTypography.bodySmall),
                  avatar: const Icon(Icons.home_outlined, size: 16),
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Leader cells sheet ─────────────────────────────────────────────────────

class _LeaderCellsSheet extends StatefulWidget {
  const _LeaderCellsSheet({required this.leader, required this.dio});
  final _LeaderData leader;
  final Dio dio;

  @override
  State<_LeaderCellsSheet> createState() => _LeaderCellsSheetState();
}

class _LeaderCellsSheetState extends State<_LeaderCellsSheet> {
  bool _loading = false;
  List<_CellDetail> _cellDetails = [];

  @override
  void initState() {
    super.initState();
    _loadCells();
  }

  Future<void> _loadCells() async {
    setState(() => _loading = true);
    final details = <_CellDetail>[];
    for (final cell in widget.leader.cells) {
      try {
        final resp = await widget.dio.get('/cells/${cell.id}');
        final cellData =
            (resp.data as Map<String, dynamic>)['cell'] as Map<String, dynamic>;
        final membResp = await widget.dio.get('/cells/${cell.id}/members');
        final membCount =
            ((membResp.data as Map<String, dynamic>)['members'] as List).length;
        details.add(_CellDetail.fromJson(cellData, membCount));
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _cellDetails = details;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final leader = widget.leader;
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, ctrl) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePaddingH,
          AppSpacing.md,
          AppSpacing.pagePaddingH,
          0,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('Células de ${leader.name}', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.base),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_cellDetails.isEmpty)
              const Expanded(
                child: Center(child: Text('Nenhuma célula encontrada')),
              )
            else
              Expanded(
                child: ListView.separated(
                  controller: ctrl,
                  itemCount: _cellDetails.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    final c = _cellDetails[i];
                    return AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name, style: AppTypography.titleSmall),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${c.neighborhood}, ${c.city}',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_outlined,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${c.dayOfWeek} às ${c.time}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const Spacer(),
                              const Icon(
                                Icons.people_outline,
                                size: 14,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${c.memberCount} membros',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
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

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2 — OVERVIEW
// ═══════════════════════════════════════════════════════════════════════════

class _OverviewTab extends StatefulWidget {
  const _OverviewTab();

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  late final Dio _dio;
  bool _loading = true;
  int _totalLeaders = 0;
  int _totalCells = 0;
  int _totalMembers = 0;

  @override
  void initState() {
    super.initState();
    _dio = DioClient(AuthStorage()).dio;
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    try {
      final resp = await _dio.get('/users/my-leaders');
      final leaders =
          (resp.data as Map<String, dynamic>)['leaders'] as List? ?? [];
      int cells = 0;
      int members = 0;
      for (final l in leaders) {
        final leaderId = l['id'] as String;
        try {
          final cResp = await _dio.get(
            '/cells',
            queryParameters: {'leaderId': leaderId},
          );
          final cellList =
              (cResp.data as Map<String, dynamic>)['cells'] as List? ?? [];
          cells += cellList.length;
          for (final c in cellList) {
            final membResp = await _dio.get('/cells/${c['id']}/members');
            members +=
                ((membResp.data as Map<String, dynamic>)['members'] as List)
                    .length;
          }
        } catch (_) {}
      }
      if (!mounted) return;
      setState(() {
        _totalLeaders = leaders.length;
        _totalCells = cells;
        _totalMembers = members;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        children: [
          AppSectionHeader(title: 'Visão Geral'),
          const SizedBox(height: AppSpacing.base),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.people,
                  label: 'Líderes',
                  value: '$_totalLeaders',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _StatCard(
                  icon: Icons.home,
                  label: 'Células',
                  value: '$_totalCells',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatCard(
            icon: Icons.group,
            label: 'Total de Membros',
            value: '$_totalMembers',
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.base),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 28),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: AppTypography.displaySmall),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Data models
// ═══════════════════════════════════════════════════════════════════════════

class _LeaderData {
  final String id;
  final String name;
  final String email;
  final List<_CellSummary> cells;

  const _LeaderData({
    required this.id,
    required this.name,
    required this.email,
    required this.cells,
  });

  factory _LeaderData.fromJson(
    Map<String, dynamic> json,
    List<_CellSummary> cells,
  ) {
    return _LeaderData(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      cells: cells,
    );
  }
}

class _CellSummary {
  final String id;
  final String name;

  const _CellSummary({required this.id, required this.name});

  factory _CellSummary.fromJson(Map<String, dynamic> json) => _CellSummary(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
  );
}

class _CellDetail {
  final String id;
  final String name;
  final String neighborhood;
  final String city;
  final String dayOfWeek;
  final String time;
  final int memberCount;

  const _CellDetail({
    required this.id,
    required this.name,
    required this.neighborhood,
    required this.city,
    required this.dayOfWeek,
    required this.time,
    required this.memberCount,
  });

  factory _CellDetail.fromJson(Map<String, dynamic> json, int memberCount) =>
      _CellDetail(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        neighborhood: json['neighborhood'] as String? ?? '',
        city: json['city'] as String? ?? '',
        dayOfWeek: json['dayOfWeek'] as String? ?? '',
        time: json['time'] as String? ?? '',
        memberCount: memberCount,
      );
}
