import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../design_system/design_system.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../injection/injection.dart';
import '../../data/church_remote_datasource.dart';

/// Painel do dono do SaaS (SUPERADMIN): gestão de igrejas/planos e dashboard de uso.
class SuperAdminPage extends StatefulWidget {
  const SuperAdminPage({super.key});

  @override
  State<SuperAdminPage> createState() => _SuperAdminPageState();
}

class _SuperAdminPageState extends State<SuperAdminPage>
    with SingleTickerProviderStateMixin {
  final _ds = getIt<ChurchRemoteDatasource>();
  static const _tiers = ['FREE', 'STARTER', 'GROWTH', 'COMPLETE'];

  late final TabController _tabController;

  List<Map<String, dynamic>> _churches = const [];
  bool _loading = true;

  Map<String, dynamic>? _usage;
  bool _usageLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
    _loadUsage();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await _ds.listChurches();
      if (mounted) setState(() => _churches = list);
    } catch (e) {
      _snack('Erro ao carregar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadUsage() async {
    setState(() => _usageLoading = true);
    try {
      final usage = await _ds.getUsage();
      if (mounted) setState(() => _usage = usage);
    } catch (e) {
      _snack('Erro ao carregar uso: $e');
    } finally {
      if (mounted) setState(() => _usageLoading = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(
        title: const Text('Painel SaaS'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Igrejas', icon: Icon(Icons.church_outlined)),
            Tab(
              text: 'Uso do Sistema',
              icon: Icon(Icons.insert_chart_outlined_rounded),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Gerenciar planos',
            onPressed: () => context.push(AppRoutes.superAdminPlans),
            icon: const Icon(Icons.workspace_premium_outlined),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: () {
              _load();
              _loadUsage();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: () {
              getIt<AuthBloc>().add(const AuthLogoutRequested());
              context.go(AppRoutes.login);
            },
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) => _tabController.index == 0
            ? FloatingActionButton.extended(
                onPressed: _createChurchDialog,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nova igreja'),
              )
            : const SizedBox.shrink(),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _loading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
                    itemCount: _churches.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) => _churchTile(_churches[i]),
                  ),
                ),
          _usageLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadUsage,
                  child: _usage == null
                      ? ListView(
                          children: [
                            AppEmptyState(
                              title: 'Sem dados de uso',
                              subtitle: 'Puxe pra baixo para tentar novamente.',
                              icon: Icons.insert_chart_outlined_rounded,
                            ),
                          ],
                        )
                      : _usageDashboard(_usage!),
                ),
        ],
      ),
    );
  }

  // ── Uso do sistema ─────────────────────────────────────────────────────────

  Widget _usageDashboard(Map<String, dynamic> usage) {
    final totals = usage['totals'] as Map<String, dynamic>;
    final leaders = totals['leaders'] as Map<String, dynamic>;
    final churches = (usage['churches'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final totalLeaders =
        (leaders['lider'] as int) +
        (leaders['supervisor'] as int) +
        (leaders['coordenador'] as int);

    return ListView(
      padding: EdgeInsets.all(
        isDesktop ? AppSpacing.pagePaddingV : AppSpacing.pagePaddingH,
      ),
      children: [
        const AppSectionHeader(title: 'Visão geral'),
        const SizedBox(height: AppSpacing.sm),
        GridView.custom(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: AppBreakpoints.kpiColumns(context, itemCount: 7),
            crossAxisSpacing: AppSpacing.base,
            mainAxisSpacing: AppSpacing.base,
            mainAxisExtent: 148,
          ),
          childrenDelegate: SliverChildListDelegate([
            StatCard(
              label: 'Igrejas ativas',
              value: '${totals['activeChurches']}/${totals['churches']}',
              icon: Icons.church_outlined,
              color: AppColors.primary,
              onTap: () => _openChurchesUsage(churches),
            ),
            StatCard(
              label: 'Membros',
              value: '${totals['membersCount']}',
              icon: Icons.groups_outlined,
              color: AppColors.secondary,
            ),
            StatCard(
              label: 'Células',
              value: '${totals['cellsCount']}',
              icon: Icons.groups_2_outlined,
              color: AppColors.roxo,
            ),
            StatCard(
              label: 'Visitantes',
              value: '${totals['visitorsCount']}',
              icon: Icons.people_alt_outlined,
              color: AppColors.accent,
            ),
            StatCard(
              label: 'Líderes',
              value: '$totalLeaders',
              icon: Icons.record_voice_over_outlined,
              color: AppColors.info,
            ),
            StatCard(
              label: 'Coordenações',
              value: '${leaders['coordenacoes']}',
              icon: Icons.hub_outlined,
              color: AppColors.warning,
            ),
            StatCard(
              label: 'Armazenamento',
              value: _formatBytes(totals['storageBytes'] as int),
              icon: Icons.cloud_outlined,
              color: AppColors.success,
            ),
          ]),
        ),
      ],
    );
  }

  void _openChurchesUsage(List<Map<String, dynamic>> churches) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ChurchesUsagePage(churches: churches),
      ),
    );
  }

  // ── Igrejas (gestão) ────────────────────────────────────────────────────────

  /// O backend devolve o enum cru (`TRIALING`, `MANUAL`…). Sem tradução ele
  /// aparecia em inglês e em caixa alta no meio de badges em português.
  static String _subscriptionStatusLabel(String raw) =>
      switch (raw.toUpperCase()) {
        'TRIALING' => 'Em teste',
        'ACTIVE' => 'Ativa',
        'PAST_DUE' => 'Em atraso',
        'CANCELED' || 'CANCELLED' => 'Cancelada',
        'MANUAL' => 'Manual',
        'INCOMPLETE' => 'Incompleta',
        'UNPAID' => 'Não paga',
        _ => raw,
      };

  Widget _churchTile(Map<String, dynamic> c) {
    final plan = c['plan'] as Map<String, dynamic>?;
    final status = c['subscriptionStatus'] as String?;
    final active = c['isActive'] as bool? ?? true;
    return AppCard(
      child: Row(
        children: [
          Container(
            width: AppSpacing.avatarMd,
            height: AppSpacing.avatarMd,
            decoration: BoxDecoration(
              color: active ? AppColors.successLight : AppColors.errorLight,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(
              Icons.church_rounded,
              color: active ? AppColors.success : AppColors.error,
              size: AppSpacing.iconMd,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c['name'] as String? ?? '—',
                  style: AppTypography.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs2),
                Row(
                  children: [
                    AppBadge(
                      label: plan?['name'] as String? ?? 'sem plano',
                      variant: AppBadgeVariant.primary,
                      size: AppBadgeSize.sm,
                      icon: Icons.workspace_premium_outlined,
                    ),
                    if (status != null) ...[
                      const SizedBox(width: AppSpacing.xs),
                      AppBadge(
                        label: _subscriptionStatusLabel(status),
                        variant: AppBadgeVariant.neutral,
                        size: AppBadgeSize.sm,
                      ),
                    ],
                    if (!active) ...[
                      const SizedBox(width: AppSpacing.xs),
                      const AppBadge(
                        label: 'Inativa',
                        variant: AppBadgeVariant.error,
                        size: AppBadgeSize.sm,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            onSelected: (v) => _onAction(v, c),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'plan',
                child: ListTile(
                  leading: Icon(Icons.workspace_premium_outlined),
                  title: Text('Alterar plano'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'toggle',
                child: ListTile(
                  leading: Icon(
                    active
                        ? Icons.block_outlined
                        : Icons.check_circle_outline_rounded,
                  ),
                  title: Text(active ? 'Desativar' : 'Ativar'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _onAction(String action, Map<String, dynamic> c) async {
    final id = c['id'] as String;
    if (action == 'toggle') {
      try {
        await _ds.setChurchActive(
          churchId: id,
          isActive: !(c['isActive'] as bool? ?? true),
        );
        await _load();
      } catch (e) {
        _snack('Erro: $e');
      }
    } else if (action == 'plan') {
      await _assignPlanDialog(id);
    }
  }

  Future<void> _assignPlanDialog(String churchId) async {
    String tier = _tiers.first;
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Atribuir plano'),
        content: StatefulBuilder(
          builder: (ctx, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            children: _tiers
                .map(
                  (t) => InkWell(
                    onTap: () => setLocal(() => tier = t),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            tier == t
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                          ),
                          const SizedBox(width: 12),
                          Text(t),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, tier),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (selected == null) return;
    try {
      await _ds.assignPlan(churchId: churchId, planTier: selected);
      await _load();
      _snack('Plano atribuído: $selected');
    } catch (e) {
      _snack('Erro: $e');
    }
  }

  Future<void> _createChurchDialog() async {
    final churchName = TextEditingController();
    final adminName = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    String tier = _tiers.first;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nova igreja'),
        content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (ctx, setLocal) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dlgField(churchName, 'Nome da igreja'),
                _dlgField(adminName, 'Nome do admin'),
                _dlgField(email, 'E-mail do admin'),
                _dlgField(password, 'Senha', obscure: true),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: tier,
                  decoration: const InputDecoration(labelText: 'Plano'),
                  items: _tiers
                      .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                      .toList(),
                  onChanged: (v) => setLocal(() => tier = v ?? tier),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Criar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _ds.createChurch(
        churchName: churchName.text.trim(),
        adminName: adminName.text.trim(),
        adminEmail: email.text.trim(),
        adminPassword: password.text,
        planTier: tier,
      );
      await _load();
      _snack('Igreja criada');
    } catch (e) {
      _snack('Erro ao criar: $e');
    }
  }

  Widget _dlgField(
    TextEditingController c,
    String label, {
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        obscureText: obscure,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }
}

/// Tela de detalhe: uso por igreja (aberta a partir do card "Igrejas ativas").
class _ChurchesUsagePage extends StatelessWidget {
  const _ChurchesUsagePage({required this.churches});

  final List<Map<String, dynamic>> churches;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      appBar: AppBar(title: Text('Igrejas (${churches.length})')),
      body: churches.isEmpty
          ? const Center(
              child: AppEmptyState(title: 'Nenhuma igreja cadastrada.'),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
              itemCount: churches.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, i) => _churchUsageCard(churches[i]),
            ),
    );
  }
}

// ── Helpers de uso por igreja (compartilhados entre dashboard e detalhe) ──────

Widget _churchUsageCard(Map<String, dynamic> c) {
  final leaders = c['leaders'] as Map<String, dynamic>;
  final active = c['isActive'] as bool? ?? true;

  return AppCard(
    padding: const EdgeInsets.all(AppSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: active ? AppColors.successLight : AppColors.errorLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Icon(
                Icons.church_rounded,
                color: active ? AppColors.success : AppColors.error,
                size: AppSpacing.iconSm,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                c['churchName'] as String? ?? '—',
                style: AppTypography.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppBadge(
              label: c['planTier'] as String? ?? 'sem plano',
              variant: AppBadgeVariant.primary,
              size: AppBadgeSize.sm,
            ),
            if (!active) ...[
              const SizedBox(width: AppSpacing.xs),
              const AppBadge(
                label: 'Inativa',
                variant: AppBadgeVariant.error,
                size: AppBadgeSize.sm,
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        const Divider(height: 1),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.xl,
          runSpacing: AppSpacing.md,
          children: [
            _usageMetric(
              Icons.groups_outlined,
              'Membros',
              '${c['membersCount']}',
            ),
            _usageMetric(
              Icons.groups_2_outlined,
              'Células',
              '${c['cellsCount']}',
            ),
            _usageMetric(
              Icons.people_alt_outlined,
              'Visitantes',
              '${c['visitorsCount']}',
            ),
            _usageMetric(
              Icons.record_voice_over_outlined,
              'Líderes',
              '${leaders['lider']}',
            ),
            _usageMetric(
              Icons.supervisor_account_outlined,
              'Supervisores',
              '${leaders['supervisor']}',
            ),
            _usageMetric(
              Icons.assignment_ind_outlined,
              'Coordenadores',
              '${leaders['coordenador']}',
            ),
            _usageMetric(
              Icons.hub_outlined,
              'Coordenações',
              '${leaders['coordenacoes']}',
            ),
            _usageMetric(
              Icons.cloud_outlined,
              'Armazenamento',
              _formatBytes(c['storageBytes'] as int),
            ),
          ],
        ),
      ],
    ),
  );
}

Widget _usageMetric(IconData icon, String label, String value) {
  return Builder(
    builder: (context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: AppSpacing.iconXs,
            color: isDark ? AppColors.text3Dark : AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            value,
            style: AppTypography.labelLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(width: AppSpacing.xs2),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: isDark ? AppColors.text3Dark : AppColors.textTertiary,
            ),
          ),
        ],
      );
    },
  );
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
