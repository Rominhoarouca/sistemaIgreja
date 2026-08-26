import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/reset_password_sheet.dart';
import '../../../supervisor/presentation/pages/supervisor_home_page.dart';
import 'coordinator_dashboard_tab.dart';
import '../../../../injection/injection.dart';
import '../../../../shared/utils/plural.dart';

/// Painel do Coordenador — coordena supervisores, seus líderes e células.
/// Abas: Início (dashboard) · Supervisores · Líderes · Células.
/// As abas Líderes e Células reutilizam os widgets do supervisor: o backend
/// escopa `/users/my-leaders` pela coordenação quando o papel é COORDENADOR.
class CoordinatorHomePage extends StatefulWidget {
  const CoordinatorHomePage({super.key});

  @override
  State<CoordinatorHomePage> createState() => _CoordinatorHomePageState();
}

class _CoordinatorHomePageState extends State<CoordinatorHomePage> {
  int _selectedTab = 0;

  static const _tabs = [
    NavigationDestination(
      icon: Icon(Icons.grid_view_outlined),
      selectedIcon: Icon(Icons.grid_view_rounded),
      label: 'Início',
    ),
    NavigationDestination(
      icon: Icon(Icons.supervisor_account_outlined),
      selectedIcon: Icon(Icons.supervisor_account),
      label: 'Supervisores',
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final appBar = AppBar(
      title: const Text('Painel do Coordenador'),
      elevation: 0,
      actions: [
        IconButton(
          tooltip: isDark ? 'Modo claro' : 'Modo escuro',
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
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
        CoordinatorDashboardTab(),
        _SupervisorsTab(),
        SupervisedLeadersTab(),
        SupervisedCellsTab(),
      ],
    );

    if (isWide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedTab,
              onDestinationSelected: (i) => setState(() => _selectedTab = i),
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final d in _tabs)
                  NavigationRailDestination(
                    icon: d.icon,
                    selectedIcon: d.selectedIcon,
                    label: Text(d.label),
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
// TAB 2 — SUPERVISORES
// ═══════════════════════════════════════════════════════════════════════════

class _SupervisorsTab extends StatefulWidget {
  const _SupervisorsTab();

  @override
  State<_SupervisorsTab> createState() => _SupervisorsTabState();
}

class _SupervisorsTabState extends State<_SupervisorsTab> {
  late final Dio _dio;
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  String _query = '';
  List<Map<String, dynamic>> _supervisors = [];

  /// Líderes por supervisor (nomes), para exibir nos cards.
  final Map<String, List<String>> _leadersBySupervisor = {};

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
      final results = await Future.wait([
        _dio.get('/users/my-supervisors'),
        _dio.get('/users/my-leaders'),
      ]);
      final supervisors =
          ((results[0].data as Map<String, dynamic>)['supervisors'] as List? ??
                  [])
              .cast<Map<String, dynamic>>();
      final leaders =
          ((results[1].data as Map<String, dynamic>)['leaders'] as List? ?? [])
              .cast<Map<String, dynamic>>();

      _leadersBySupervisor.clear();
      for (final l in leaders) {
        final supId = (l['supervisorId'] as String?) ?? '';
        _leadersBySupervisor
            .putIfAbsent(supId, () => [])
            .add((l['name'] as String?) ?? '');
      }

      if (!mounted) return;
      setState(() {
        _supervisors = supervisors;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar supervisores';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _supervisors;
    return _supervisors
        .where(
          (s) =>
              ((s['name'] as String?) ?? '').toLowerCase().contains(q) ||
              ((s['email'] as String?) ?? '').toLowerCase().contains(q),
        )
        .toList();
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
            hint: 'Pesquisar supervisor...',
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: AppSpacing.base),
          AppSectionHeader(
            title: 'Supervisores da coordenação (${filtered.length})',
          ),
          const SizedBox(height: AppSpacing.sm),
          if (filtered.isEmpty)
            const AppEmptyState(
              title: 'Nenhum supervisor encontrado',
              subtitle:
                  'Solicite ao administrador que associe supervisores à sua coordenação.',
              icon: Icons.supervisor_account_outlined,
            )
          else
            ...filtered.map((s) {
              final id = (s['id'] as String?) ?? '';
              final name = (s['name'] as String?) ?? '';
              final email = (s['email'] as String?) ?? '';
              final leaderNames = _leadersBySupervisor[id] ?? const [];
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          AppAvatar(
                            initials: name
                                .trim()
                                .split(RegExp(r'\s+'))
                                .where((e) => e.isNotEmpty)
                                .map((e) => e[0].toUpperCase())
                                .take(2)
                                .join(),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: AppTypography.titleSmall),
                                if (email.isNotEmpty)
                                  Text(
                                    email,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
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
                              userId: id,
                              userName: name,
                            ),
                          ),
                          AppBadge(
                            label: plural(
                              leaderNames.length,
                              'líder',
                              'líderes',
                            ),
                            variant: AppBadgeVariant.primary,
                            size: AppBadgeSize.sm,
                          ),
                        ],
                      ),
                      if (leaderNames.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.sm),
                        const Divider(height: 1),
                        const SizedBox(height: AppSpacing.sm),
                        Wrap(
                          spacing: AppSpacing.xs,
                          runSpacing: AppSpacing.xs,
                          children: leaderNames
                              .map(
                                (n) => Chip(
                                  label: Text(
                                    n,
                                    style: AppTypography.bodySmall,
                                  ),
                                  avatar: const Icon(
                                    Icons.person_outline,
                                    size: 16,
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
