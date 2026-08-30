import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/address_selector.dart';
import '../../../../shared/widgets/reset_password_sheet.dart';
import 'supervisor_dashboard_tab.dart';
import '../../../../injection/injection.dart';
import '../../../../shared/widgets/app_map_tiles.dart';
import '../../../../shared/widgets/cell_type_badge.dart';
import '../../../../core/constants/app_constants.dart';

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
      icon: Icon(Icons.grid_view_outlined),
      selectedIcon: Icon(Icons.grid_view_rounded),
      label: 'Início',
    ),
    NavigationDestination(
      icon: Icon(Icons.people_outline),
      selectedIcon: Icon(Icons.people),
      label: 'Líderes',
    ),
    NavigationDestination(
      icon: Icon(Icons.groups_2_outlined),
      selectedIcon: Icon(Icons.groups_2),
      label: 'Células',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;

    final appBar = AppBar(
      title: const Text('Painel do Supervisor'),
      elevation: 0,
      actions: [
        IconButton(
          tooltip: 'Álbuns dos encontros',
          icon: const Icon(Icons.photo_library_outlined),
          onPressed: () => context.push(AppRoutes.albums),
        ),
        IconButton(
          tooltip: Theme.of(context).brightness == Brightness.dark
              ? 'Modo claro'
              : 'Modo escuro',
          icon: Icon(
            Theme.of(context).brightness == Brightness.dark
                ? Icons.light_mode_outlined
                : Icons.dark_mode_outlined,
          ),
          onPressed: () => ThemeController.instance.toggle(context),
        ),
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
      children: const [
        SupervisorDashboardTab(),
        SupervisedLeadersTab(),
        SupervisedCellsTab(),
      ],
    );

    if (isWide) {
      return Scaffold(
        appBar: appBar,
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedTab,
              onDestinationSelected: (i) => setState(() => _selectedTab = i),
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view_rounded),
                  label: Text('Início'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people),
                  label: Text('Líderes'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.groups_2_outlined),
                  selectedIcon: Icon(Icons.groups_2),
                  label: Text('Células'),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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

class SupervisedLeadersTab extends StatefulWidget {
  const SupervisedLeadersTab({super.key});

  @override
  State<SupervisedLeadersTab> createState() => SupervisedLeadersTabState();
}

class SupervisedLeadersTabState extends State<SupervisedLeadersTab> {
  late final Dio _dio;
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  String _query = '';
  List<SupervisedLeaderData> _leaders = [];

  @override
  void initState() {
    super.initState();
    _dio = getIt<DioClient>().dio;
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
      final leaders = <SupervisedLeaderData>[];
      for (final item in data) {
        final userId = item['id'] as String;
        List<SupervisedCellSummary> cells = [];
        try {
          final cellResp = await _dio.get(
            '/cells',
            queryParameters: {'leaderId': userId},
          );
          final cellList =
              (cellResp.data as Map<String, dynamic>)['cells'] as List? ?? [];
          cells = cellList
              .map(
                (c) =>
                    SupervisedCellSummary.fromJson(c as Map<String, dynamic>),
              )
              .toList();
        } catch (_) {
          // fallback: try my-cell style
        }
        leaders.add(
          SupervisedLeaderData.fromJson(item as Map<String, dynamic>, cells),
        );
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

  List<SupervisedLeaderData> get _filtered {
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
                child: SupervisedLeaderCard(
                  leader: l,
                  onViewCells: () => _showCellsSheet(context, l),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showCellsSheet(BuildContext context, SupervisedLeaderData leader) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => LeaderCellsSheet(leader: leader, dio: _dio),
    );
  }
}

// ── Leader card ────────────────────────────────────────────────────────────

class SupervisedLeaderCard extends StatelessWidget {
  const SupervisedLeaderCard({
    super.key,
    required this.leader,
    required this.onViewCells,
  });

  final SupervisedLeaderData leader;
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
              IconButton(
                tooltip: 'Redefinir senha',
                icon: const Icon(Icons.lock_reset, size: 20),
                visualDensity: VisualDensity.compact,
                onPressed: () => showResetPasswordSheet(
                  context,
                  userId: leader.id,
                  userName: leader.name,
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

class LeaderCellsSheet extends StatefulWidget {
  const LeaderCellsSheet({super.key, required this.leader, required this.dio});
  final SupervisedLeaderData leader;
  final Dio dio;

  @override
  State<LeaderCellsSheet> createState() => LeaderCellsSheetState();
}

class LeaderCellsSheetState extends State<LeaderCellsSheet> {
  bool _loading = false;
  List<CellDetail> _cellDetails = [];
  List<LeaderOption> _availableLeaders = [];
  List<CellTypeOption> _cellTypes = [];

  @override
  void initState() {
    super.initState();
    _loadCells();
    _loadLeadersAndTypes();
  }

  Future<void> _loadLeadersAndTypes() async {
    try {
      // Load all supervisors' leaders
      final leadersResp = await widget.dio.get('/users/my-leaders');
      final leadersList =
          (leadersResp.data as Map<String, dynamic>)['leaders'] as List? ?? [];
      final leaders = leadersList
          .map(
            (l) => LeaderOption(
              id: l['id'] as String,
              name: l['name'] as String? ?? '',
            ),
          )
          .toList();

      // Load cell types
      List<CellTypeOption> types = [];
      try {
        final typesResp = await widget.dio.get('/cell-types');
        final typesList =
            (typesResp.data as Map<String, dynamic>)['cellTypes'] as List? ??
            [];
        types = typesList
            .map(
              (t) => CellTypeOption(
                id: t['id'] as String,
                name: t['name'] as String? ?? '',
              ),
            )
            .toList();
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _availableLeaders = leaders;
        _cellTypes = types;
      });
    } catch (_) {}
  }

  Future<void> _loadCells() async {
    setState(() => _loading = true);
    final details = <CellDetail>[];
    for (final cell in widget.leader.cells) {
      try {
        final resp = await widget.dio.get('/cells/${cell.id}');
        final cellData =
            (resp.data as Map<String, dynamic>)['cell'] as Map<String, dynamic>;
        final membResp = await widget.dio.get('/cells/${cell.id}/members');
        final membCount =
            ((membResp.data as Map<String, dynamic>)['members'] as List).length;
        details.add(CellDetail.fromJson(cellData, membCount));
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _cellDetails = details;
      _loading = false;
    });
  }

  Future<void> _editCell(CellDetail cell) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => EditCellDetailsSheet(
        dio: widget.dio,
        cell: cell,
        availableLeaders: _availableLeaders,
        cellTypes: _cellTypes,
      ),
    );
    if (changed == true) {
      await _loadCells();
    }
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
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) {
                    final c = _cellDetails[i];
                    return AppCard(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      c.name,
                                      style: AppTypography.titleSmall,
                                    ),
                                    if (CellTypeBadge.has(c.cellTypeName))
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: AppSpacing.xs2,
                                        ),
                                        child: CellTypeBadge(
                                          typeName: c.cellTypeName,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                onPressed: () => _editCell(c),
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ),
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

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3 — CÉLULAS (gestão das células supervisionadas)
// ═══════════════════════════════════════════════════════════════════════════

class SupervisedCellsTab extends StatefulWidget {
  const SupervisedCellsTab({super.key});

  @override
  State<SupervisedCellsTab> createState() => SupervisedCellsTabState();
}

class SupervisedCellsTabState extends State<SupervisedCellsTab> {
  late final Dio _dio;
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  String _query = '';
  List<CellDetail> _cells = [];
  List<LeaderOption> _availableLeaders = [];
  List<CellTypeOption> _cellTypes = [];

  @override
  void initState() {
    super.initState();
    _dio = getIt<DioClient>().dio;
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
      final resp = await _dio.get('/users/my-leaders');
      final leaders =
          ((resp.data as Map<String, dynamic>)['leaders'] as List? ?? [])
              .cast<Map<String, dynamic>>();
      _availableLeaders = leaders
          .map(
            (l) => LeaderOption(
              id: l['id'] as String,
              name: l['name'] as String? ?? '',
            ),
          )
          .toList();

      try {
        final typesResp = await _dio.get('/cell-types');
        final typesList =
            (typesResp.data as Map<String, dynamic>)['cellTypes'] as List? ??
            [];
        _cellTypes = typesList
            .map(
              (t) => CellTypeOption(
                id: t['id'] as String,
                name: t['name'] as String? ?? '',
              ),
            )
            .toList();
      } catch (_) {}

      final details = <CellDetail>[];
      await Future.wait(
        leaders.map((l) async {
          final cellsResp = await _dio.get(
            '/cells',
            queryParameters: {'leaderId': l['id']},
          );
          final cellList =
              ((cellsResp.data as Map<String, dynamic>)['cells'] as List? ?? [])
                  .cast<Map<String, dynamic>>();
          await Future.wait(
            cellList.map((c) async {
              try {
                final cellResp = await _dio.get('/cells/${c['id']}');
                final cellData =
                    (cellResp.data as Map<String, dynamic>)['cell']
                        as Map<String, dynamic>;
                final membResp = await _dio.get('/cells/${c['id']}/members');
                final membCount =
                    ((membResp.data as Map<String, dynamic>)['members'] as List)
                        .length;
                details.add(CellDetail.fromJson(cellData, membCount));
              } catch (_) {}
            }),
          );
        }),
      );
      details.sort((a, b) => a.name.compareTo(b.name));

      if (!mounted) return;
      setState(() {
        _cells = details;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar células';
        _loading = false;
      });
    }
  }

  List<CellDetail> get _filtered {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _cells;
    return _cells
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.leaderName.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _editCell(CellDetail cell) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => EditCellDetailsSheet(
        dio: _dio,
        cell: cell,
        availableLeaders: _availableLeaders,
        cellTypes: _cellTypes,
      ),
    );
    if (changed == true) _loadData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

    final filtered = _filtered;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        children: [
          AppSearchField(
            hint: 'Pesquisar célula ou líder...',
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: AppSpacing.base),
          AppSectionHeader(
            title: 'Células supervisionadas (${filtered.length})',
          ),
          const SizedBox(height: AppSpacing.sm),
          if (filtered.isEmpty)
            const AppEmptyState(
              title: 'Nenhuma célula encontrada',
              subtitle: 'As células dos seus líderes aparecerão aqui.',
              icon: Icons.groups_2_outlined,
            )
          else
            ...filtered.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  onTap: () => _editCell(c),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              c.name,
                              style: AppTypography.titleSmall,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Editar célula',
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            onPressed: () => _editCell(c),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Líder: ${c.leaderName}',
                              style: AppTypography.bodySmall.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (CellTypeBadge.has(c.cellTypeName)) ...[
                            const SizedBox(width: AppSpacing.xs),
                            CellTypeBadge(typeName: c.cellTypeName),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today_outlined,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${c.dayOfWeek} às ${c.time}',
                            style: AppTypography.bodySmall.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.people_outline,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${c.memberCount} membros',
                            style: AppTypography.bodySmall.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Edit Cell Sheet ───────────────────────────────────────────────────────

class EditCellDetailsSheet extends StatefulWidget {
  const EditCellDetailsSheet({
    super.key,
    required this.dio,
    required this.cell,
    required this.availableLeaders,
    required this.cellTypes,
  });

  final Dio dio;
  final CellDetail cell;
  final List<LeaderOption> availableLeaders;
  final List<CellTypeOption> cellTypes;

  @override
  State<EditCellDetailsSheet> createState() => EditCellDetailsSheetState();
}

class EditCellDetailsSheetState extends State<EditCellDetailsSheet> {
  late String _selectedLeaderId;
  late String? _selectedCellTypeId;

  // Address state
  late final TextEditingController _cepCtrl;
  late final TextEditingController _addressCtrl;
  String? _bairroId;
  String? _estadoId; // used only for AddressSelector initial pre-fill
  String? _cidadeId; // used only for AddressSelector initial pre-fill

  // Map / coordinates
  double? _latitude;
  double? _longitude;
  late final MapController _mapController;

  bool _cepLoading = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedLeaderId = widget.cell.leaderId;
    _selectedCellTypeId = widget.cell.cellTypeId;
    _cepCtrl = TextEditingController();
    _addressCtrl = TextEditingController(text: widget.cell.address);
    _bairroId = widget.cell.bairroId;
    _estadoId = widget.cell.estadoId;
    _cidadeId = widget.cell.cidadeId;
    _latitude = widget.cell.latitude;
    _longitude = widget.cell.longitude;
    _mapController = MapController();
  }

  @override
  void dispose() {
    _cepCtrl.dispose();
    _addressCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ── CEP lookup ────────────────────────────────────────────────────────────

  Future<void> _lookupCep(String cep) async {
    final cleaned = cep.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length != 8) return;

    setState(() => _cepLoading = true);
    try {
      final resp = await Dio().get('https://viacep.com.br/ws/$cleaned/json/');
      final data = resp.data as Map<String, dynamic>;
      if (data['erro'] == true) {
        setState(() => _cepLoading = false);
        return;
      }

      final logradouro = data['logradouro'] as String? ?? '';
      final bairroName = data['bairro'] as String? ?? '';
      final localidade = data['localidade'] as String? ?? '';
      final uf = data['uf'] as String? ?? '';

      String? foundEstadoId;
      String? foundCidadeId;
      String? foundBairroId;
      double? foundLat;
      double? foundLng;

      try {
        final estadosResp = await widget.dio.get('/location/estados');
        final estadosList =
            (estadosResp.data as Map<String, dynamic>)['estados'] as List;

        for (final e in estadosList) {
          final estado = e as Map<String, dynamic>;
          if ((estado['uf'] as String?)?.toUpperCase() == uf.toUpperCase()) {
            foundEstadoId = estado['id'] as String;
            break;
          }
        }

        if (foundEstadoId != null) {
          final cidadesResp = await widget.dio.get(
            '/location/estados/$foundEstadoId/cidades',
          );
          final cidadesList =
              (cidadesResp.data as Map<String, dynamic>)['cidades'] as List;

          for (final c in cidadesList) {
            final cidade = c as Map<String, dynamic>;
            if ((cidade['name'] as String?)?.trim().toLowerCase() ==
                localidade.trim().toLowerCase()) {
              foundCidadeId = cidade['id'] as String;
              break;
            }
          }

          if (foundCidadeId != null) {
            final bairrosResp = await widget.dio.get(
              '/location/cidades/$foundCidadeId/bairros',
            );
            final bairrosList =
                (bairrosResp.data as Map<String, dynamic>)['bairros'] as List;

            for (final b in bairrosList) {
              final bairroOption = b as Map<String, dynamic>;
              if ((bairroOption['name'] as String?)?.trim().toLowerCase() ==
                  bairroName.trim().toLowerCase()) {
                foundBairroId = bairroOption['id'] as String;
                foundLat = (bairroOption['latitude'] as num?)?.toDouble();
                foundLng = (bairroOption['longitude'] as num?)?.toDouble();
                break;
              }
            }
          }
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        if (logradouro.isNotEmpty) _addressCtrl.text = logradouro;
        _cepLoading = false;
        _estadoId = foundEstadoId;
        _cidadeId = foundCidadeId;
        _bairroId = foundBairroId;
        if (foundLat != null && foundLng != null) {
          _latitude = foundLat;
          _longitude = foundLng;
        }
      });

      if (foundLat != null && foundLng != null) {
        try {
          _mapController.move(LatLng(foundLat, foundLng), 15);
        } catch (_) {}
      } else if (logradouro.isNotEmpty) {
        await _geocodeWithNominatim(logradouro, localidade, uf);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _cepLoading = false);
    }
  }

  Future<void> _geocodeWithNominatim(
    String logradouro,
    String localidade,
    String uf,
  ) async {
    try {
      final query = '$logradouro, $localidade, $uf, Brasil';
      final resp = await Dio().get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'format': 'json',
          'q': query,
          'countrycodes': 'br',
          'limit': '1',
        },
        options: Options(headers: {'User-Agent': 'SistemaIgrejaApp/1.0'}),
      );
      final results = resp.data as List;
      if (results.isNotEmpty && mounted) {
        final lat = double.tryParse(results[0]['lat'] as String? ?? '');
        final lng = double.tryParse(results[0]['lon'] as String? ?? '');
        if (lat != null && lng != null) {
          setState(() {
            _latitude = lat;
            _longitude = lng;
          });
          try {
            _mapController.move(LatLng(lat, lng), 15);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updateData = <String, dynamic>{};
      if (_selectedLeaderId != widget.cell.leaderId) {
        updateData['leaderId'] = _selectedLeaderId;
      }
      if (_selectedCellTypeId != widget.cell.cellTypeId) {
        updateData['cellTypeId'] = _selectedCellTypeId;
      }
      final address = _addressCtrl.text.trim();
      if (address.isNotEmpty && address != widget.cell.address) {
        updateData['address'] = address;
      }
      if (_bairroId != widget.cell.bairroId) {
        updateData['bairroId'] = _bairroId;
      }
      if (_latitude != widget.cell.latitude) {
        updateData['latitude'] = _latitude;
      }
      if (_longitude != widget.cell.longitude) {
        updateData['longitude'] = _longitude;
      }

      if (updateData.isEmpty) {
        if (!mounted) return;
        Navigator.of(context).pop(false);
        return;
      }

      await widget.dio.patch('/cells/${widget.cell.id}', data: updateData);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?['message'] as String? ??
                'Erro ao salvar célula',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasCoords = _latitude != null && _longitude != null;
    final mapLat = _latitude ?? -14.235;
    final mapLng = _longitude ?? -51.925;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.base),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              Text('Editar Célula', style: AppTypography.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                widget.cell.name,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Líder ───────────────────────────────────────────────────
              Text('Líder', style: AppTypography.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              DropdownButton<String>(
                isExpanded: true,
                value: _selectedLeaderId,
                items: widget.availableLeaders.map((leader) {
                  return DropdownMenuItem(
                    value: leader.id,
                    child: Text(leader.name),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedLeaderId = value);
                },
              ),
              const SizedBox(height: AppSpacing.xl),

              // ── Tipo de Célula ───────────────────────────────────────────
              Text('Tipo de Célula', style: AppTypography.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              DropdownButton<String?>(
                isExpanded: true,
                value: _selectedCellTypeId,
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Nenhum tipo selecionado'),
                  ),
                  ...widget.cellTypes.map((type) {
                    return DropdownMenuItem(
                      value: type.id,
                      child: Text(type.name),
                    );
                  }),
                ],
                onChanged: (value) =>
                    setState(() => _selectedCellTypeId = value),
              ),

              // ── Endereço ─────────────────────────────────────────────────
              const SizedBox(height: AppSpacing.base),
              const Divider(),
              const SizedBox(height: AppSpacing.base),
              Text('Endereço', style: AppTypography.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              if (widget.cell.neighborhood.isNotEmpty ||
                  widget.cell.city.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Atual: ${widget.cell.address.isNotEmpty ? '${widget.cell.address}, ' : ''}${widget.cell.neighborhood}, ${widget.cell.city}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),

              // CEP
              Stack(
                children: [
                  AppTextField(
                    controller: _cepCtrl,
                    label: 'CEP (auto busca após 8 dígitos)',
                    hint: '00000-000',
                    prefixIcon: Icons.search_outlined,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    enabled: !_cepLoading,
                    inputFormatters: [
                      MaskTextInputFormatter(
                        mask: '#####-###',
                        filter: {'#': RegExp(r'[0-9]')},
                      ),
                    ],
                    onChanged: (v) {
                      final cleaned = v.replaceAll(RegExp(r'\D'), '');
                      if (cleaned.length == 8 && !_cepLoading) {
                        _lookupCep(cleaned);
                      }
                    },
                  ),
                  if (_cepLoading)
                    Positioned(
                      right: 50,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.base),

              // Logradouro
              AppTextField(
                controller: _addressCtrl,
                label: 'Logradouro',
                hint: 'Rua, avenida, etc',
                prefixIcon: Icons.home_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),

              // Estado / Cidade / Bairro
              AddressSelector(
                dio: widget.dio,
                onChanged: (id) => setState(() => _bairroId = id),
                initialEstadoId: _estadoId,
                initialCidadeId: _cidadeId,
                initialBairroId: _bairroId,
                isRequired: false,
              ),

              // ── Mapa ────────────────────────────────────────────────────
              const SizedBox(height: AppSpacing.xl),
              Text('Localização no Mapa', style: AppTypography.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                hasCoords
                    ? 'Toque no mapa para ajustar a posição da célula'
                    : 'Informe um CEP para localizar automaticamente, ou toque no mapa para definir a posição',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: LatLng(mapLat, mapLng),
                      initialZoom: hasCoords ? 15.0 : 4.0,
                      onTap: (tapPosition, point) {
                        setState(() {
                          _latitude = point.latitude;
                          _longitude = point.longitude;
                        });
                      },
                    ),
                    children: [
                      appTileLayer(),
                      if (hasCoords)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(_latitude!, _longitude!),
                              child: const Icon(
                                Icons.location_on,
                                color: AppColors.primary,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              if (hasCoords) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Lat: ${_latitude!.toStringAsFixed(6)}, Lng: ${_longitude!.toStringAsFixed(6)}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Remover'),
                      onPressed: () => setState(() {
                        _latitude = null;
                        _longitude = null;
                      }),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: _saving ? 'Salvando...' : 'Salvar',
                isLoading: _saving,
                onPressed: _saving ? null : _save,
                prefixIcon: Icons.save_outlined,
                isFullWidth: true,
              ),
              const SizedBox(height: AppSpacing.base),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Data models
// ═══════════════════════════════════════════════════════════════════════════

class SupervisedLeaderData {
  final String id;
  final String name;
  final String email;
  final List<SupervisedCellSummary> cells;

  const SupervisedLeaderData({
    required this.id,
    required this.name,
    required this.email,
    required this.cells,
  });

  factory SupervisedLeaderData.fromJson(
    Map<String, dynamic> json,
    List<SupervisedCellSummary> cells,
  ) {
    return SupervisedLeaderData(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      cells: cells,
    );
  }
}

class SupervisedCellSummary {
  final String id;
  final String name;

  const SupervisedCellSummary({required this.id, required this.name});

  factory SupervisedCellSummary.fromJson(Map<String, dynamic> json) =>
      SupervisedCellSummary(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
      );
}

class LeaderOption {
  final String id;
  final String name;

  const LeaderOption({required this.id, required this.name});
}

class CellTypeOption {
  final String id;
  final String name;

  const CellTypeOption({required this.id, required this.name});
}

class CellDetail {
  final String id;
  final String name;
  final String address;
  final String neighborhood;
  final String city;
  final String dayOfWeek;
  final String time;
  final int memberCount;
  final String leaderId;
  final String leaderName;
  final String? cellTypeId;
  final String? cellTypeName;
  final String? bairroId;
  final String? estadoId;
  final String? cidadeId;
  final double? latitude;
  final double? longitude;

  const CellDetail({
    required this.id,
    required this.name,
    required this.address,
    required this.neighborhood,
    required this.city,
    required this.dayOfWeek,
    required this.time,
    required this.memberCount,
    required this.leaderId,
    required this.leaderName,
    this.cellTypeId,
    this.cellTypeName,
    this.bairroId,
    this.estadoId,
    this.cidadeId,
    this.latitude,
    this.longitude,
  });

  factory CellDetail.fromJson(Map<String, dynamic> json, int memberCount) =>
      CellDetail(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        address: json['address'] as String? ?? '',
        neighborhood: json['neighborhood'] as String? ?? '',
        city: json['city'] as String? ?? '',
        dayOfWeek: json['dayOfWeek'] as String? ?? '',
        time: json['time'] as String? ?? '',
        memberCount: memberCount,
        leaderId: json['leaderId'] as String? ?? '',
        leaderName:
            json['leaderName'] as String? ??
            json['leader']?['name'] as String? ??
            '',
        cellTypeId: json['cellTypeId'] as String?,
        cellTypeName:
            json['cellTypeName'] as String? ??
            json['cellType']?['name'] as String?,
        bairroId: json['bairroId'] as String?,
        estadoId: json['estadoId'] as String?,
        cidadeId: json['cidadeId'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
      );
}
