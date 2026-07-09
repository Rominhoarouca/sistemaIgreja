import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/auth_storage.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/stat_detail_page.dart';

/// Destinos de navegação do perfil Líder — Início + abas da célula.
/// Índices 1..5 correspondem às abas 0..4 da gestão de célula.
const kLeaderNavDestinations = [
  NavigationDestination(
    icon: Icon(Icons.grid_view_outlined),
    selectedIcon: Icon(Icons.grid_view_rounded),
    label: 'Início',
  ),
  NavigationDestination(
    icon: Icon(Icons.people_outline),
    selectedIcon: Icon(Icons.people),
    label: 'Visitantes',
  ),
  NavigationDestination(
    icon: Icon(Icons.group_outlined),
    selectedIcon: Icon(Icons.group),
    label: 'Membros',
  ),
  NavigationDestination(
    icon: Icon(Icons.check_circle_outline),
    selectedIcon: Icon(Icons.check_circle),
    label: 'Presença',
  ),
  NavigationDestination(
    icon: Icon(Icons.auto_stories_outlined),
    selectedIcon: Icon(Icons.auto_stories),
    label: 'Materiais',
  ),
  NavigationDestination(
    icon: Icon(Icons.trending_up_outlined),
    selectedIcon: Icon(Icons.trending_up),
    label: 'Histórico',
  ),
];

/// [NavigationRailDestination]s equivalentes para telas largas.
List<NavigationRailDestination> leaderRailDestinations() => [
  for (final d in kLeaderNavDestinations)
    NavigationRailDestination(
      icon: d.icon,
      selectedIcon: d.selectedIcon,
      label: Text(d.label),
    ),
];

/// Célula do líder exibida no dashboard (dados mínimos vindos da home).
class LeaderCellInfo {
  const LeaderCellInfo({
    required this.id,
    required this.name,
    required this.dayLabel,
    required this.time,
    this.typeName,
  });

  final String id;
  final String name;
  final String dayLabel;
  final String time;
  final String? typeName;
}

/// Pessoa alcançável via WhatsApp (visitante ou membro de uma célula do líder).
class _Contact {
  _Contact({
    required this.id,
    required this.name,
    required this.phone,
    required this.cellId,
    required this.cellName,
    required this.isMember,
    this.status,
    this.createdAt,
  });

  final String id;
  final String name;
  final String phone;
  final String cellId;
  final String cellName;
  final bool isMember; // false = visitante
  final String? status; // status do visitante
  final DateTime? createdAt;
  bool selected = false;

  String get initials => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .map((e) => e[0].toUpperCase())
      .take(2)
      .join();
}

/// Home do perfil Líder — dashboard agregado das células em que ele está
/// alocado: KPIs, células, visitantes recentes e envio de WhatsApp restrito
/// a esse contexto.
class LeaderDashboardView extends StatefulWidget {
  const LeaderDashboardView({
    super.key,
    required this.cells,
    required this.onOpenCell,
    this.onNavigateTab,
    this.coordenacaoName,
    this.coordenacaoColor,
  });

  final List<LeaderCellInfo> cells;

  /// Abre a gestão da célula; [tab] escolhe a aba inicial
  /// (0 Visitantes · 1 Membros · 2 Presença · 3 Materiais · 4 Histórico).
  final void Function(LeaderCellInfo cell, {int tab}) onOpenCell;

  /// Chamado pelo menu (bottom-nav/rail) quando o líder escolhe uma aba de
  /// célula direto do dashboard (índice 0..4 da gestão de célula).
  final void Function(int tab)? onNavigateTab;
  final String? coordenacaoName;
  final Color? coordenacaoColor;

  @override
  State<LeaderDashboardView> createState() => _LeaderDashboardViewState();
}

class _LeaderDashboardViewState extends State<LeaderDashboardView> {
  late final Dio _dio;
  bool _loading = true;
  String? _error;

  final Map<String, int> _memberCount = {};
  final Map<String, int> _visitorCount = {};
  List<_Contact> _contacts = [];

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
      final contacts = <_Contact>[];
      await Future.wait(
        widget.cells.map((cell) async {
          final results = await Future.wait([
            _dio.get('/visitors', queryParameters: {'cellId': cell.id}),
            _dio.get('/cells/${cell.id}/members'),
          ]);
          final visitors =
              ((results[0].data as Map<String, dynamic>)['data'] as List? ?? [])
                  .cast<Map<String, dynamic>>();
          final members =
              ((results[1].data as Map<String, dynamic>)['members'] as List? ??
                      [])
                  .cast<Map<String, dynamic>>();
          _visitorCount[cell.id] = visitors.length;
          _memberCount[cell.id] = members.length;
          for (final v in visitors) {
            contacts.add(
              _Contact(
                id: v['id'] as String,
                name: (v['name'] as String?) ?? 'Sem nome',
                phone: (v['phone'] as String?) ?? '',
                cellId: cell.id,
                cellName: cell.name,
                isMember: false,
                status: v['status'] as String?,
                createdAt: DateTime.tryParse((v['createdAt'] as String?) ?? ''),
              ),
            );
          }
          for (final m in members) {
            contacts.add(
              _Contact(
                id: m['id'] as String,
                name: (m['name'] as String?) ?? 'Sem nome',
                phone: (m['phone'] as String?) ?? '',
                cellId: cell.id,
                cellName: cell.name,
                isMember: true,
              ),
            );
          }
        }),
      );
      if (!mounted) return;
      setState(() {
        _contacts = contacts;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar dados das células';
        _loading = false;
      });
    }
  }

  List<_Contact> get _visitors => _contacts.where((c) => !c.isMember).toList();

  List<_Contact> get _recentVisitors {
    final list = _visitors.where((c) => c.createdAt != null).toList()
      ..sort((a, b) => b.createdAt!.compareTo(a.createdAt!));
    return list.take(5).toList();
  }

  int get _integratedCount =>
      _visitors.where((c) => (c.status ?? '') == 'integrado').length;

  void _openWhatsappSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          _LeaderWhatsappSheet(cells: widget.cells, contacts: _contacts),
    );
  }

  // ── Detalhe dos KPIs ───────────────────────────────────────────────────

  static String _statusLabel(String? status) => switch (status ?? 'novo') {
    'novo' => 'Novo',
    'em_acompanhamento' => 'Em acompanhamento',
    'integrado' => 'Integrado',
    'inativo' => 'Não retornou',
    final s => s,
  };

  void _openStatDetail({
    required String title,
    required IconData icon,
    required String headerValue,
    required String subtitle,
    required List<String> columns,
    required List<List<String>> rows,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => StatDetailPage(
          title: title,
          icon: icon,
          headerValue: headerValue,
          subtitle: subtitle,
          columns: columns,
          rows: rows,
        ),
      ),
    );
  }

  void _openCellsDetail() => _openStatDetail(
    title: 'Minhas células',
    icon: Icons.groups_2_outlined,
    headerValue: '${widget.cells.length}',
    subtitle: 'Células vinculadas à sua conta',
    columns: const ['Célula', 'Dia', 'Horário', 'Membros', 'Visitantes'],
    rows: widget.cells
        .map(
          (c) => [
            c.name,
            c.dayLabel,
            c.time,
            '${_memberCount[c.id] ?? 0}',
            '${_visitorCount[c.id] ?? 0}',
          ],
        )
        .toList(),
  );

  void _openMembersDetail() {
    final members = _contacts.where((c) => c.isMember).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    _openStatDetail(
      title: 'Membros',
      icon: Icons.group_outlined,
      headerValue: '${members.length}',
      subtitle: 'Membros das suas células',
      columns: const ['Nome', 'Telefone', 'Célula'],
      rows: members
          .map((m) => [m.name, m.phone.isEmpty ? '—' : m.phone, m.cellName])
          .toList(),
    );
  }

  void _openVisitorsDetail() {
    final visitors = _visitors..sort((a, b) => a.name.compareTo(b.name));
    _openStatDetail(
      title: 'Visitantes',
      icon: Icons.people_outline,
      headerValue: '${visitors.length}',
      subtitle: 'Visitantes das suas células',
      columns: const ['Nome', 'Telefone', 'Célula', 'Status'],
      rows: visitors
          .map(
            (v) => [
              v.name,
              v.phone.isEmpty ? '—' : v.phone,
              v.cellName,
              _statusLabel(v.status),
            ],
          )
          .toList(),
    );
  }

  void _openIntegratedDetail() {
    final integrated =
        _visitors.where((c) => (c.status ?? '') == 'integrado').toList()
          ..sort((a, b) => a.name.compareTo(b.name));
    _openStatDetail(
      title: 'Integrados',
      icon: Icons.check_circle_outline,
      headerValue: '${integrated.length}',
      subtitle: 'Visitantes integrados à igreja',
      columns: const ['Nome', 'Telefone', 'Célula'],
      rows: integrated
          .map((v) => [v.name, v.phone.isEmpty ? '—' : v.phone, v.cellName])
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isWide = MediaQuery.sizeOf(context).width >= 720;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do Líder'),
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
      ),
      bottomNavigationBar: isWide || widget.cells.isEmpty
          ? null
          : NavigationBar(
              selectedIndex: 0,
              onDestinationSelected: (i) {
                if (i == 0) return;
                widget.onNavigateTab?.call(i - 1);
              },
              destinations: kLeaderNavDestinations,
            ),
      body: Column(
        children: [
          if (widget.coordenacaoColor != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePaddingH,
                vertical: AppSpacing.xs,
              ),
              color: widget.coordenacaoColor!.withValues(alpha: 0.15),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: widget.coordenacaoColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    widget.coordenacaoName ?? '',
                    style: AppTypography.labelSmall.copyWith(
                      color: widget.coordenacaoColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: isWide && widget.cells.isNotEmpty
                ? Row(
                    children: [
                      NavigationRail(
                        selectedIndex: 0,
                        onDestinationSelected: (i) {
                          if (i == 0) return;
                          widget.onNavigateTab?.call(i - 1);
                        },
                        labelType: NavigationRailLabelType.all,
                        destinations: leaderRailDestinations(),
                      ),
                      const VerticalDivider(thickness: 1, width: 1),
                      Expanded(child: _buildBody(theme)),
                    ],
                  )
                : _buildBody(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
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
    if (widget.cells.isEmpty) {
      return const Center(
        child: AppEmptyState(
          title: 'Nenhuma célula vinculada',
          subtitle: 'Aguarde o supervisor vincular uma célula à sua conta.',
          icon: Icons.group_work_outlined,
        ),
      );
    }

    final totalMembers = _memberCount.values.fold(0, (a, b) => a + b);
    final totalVisitors = _visitorCount.values.fold(0, (a, b) => a + b);
    final integrated = _integratedCount;
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: EdgeInsets.all(
          isDesktop ? AppSpacing.pagePaddingV : AppSpacing.pagePaddingH,
        ),
        children: [
          // ── KPIs ─────────────────────────────────────────────────────
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
                label: 'Minhas células',
                value: '${widget.cells.length}',
                icon: Icons.groups_2_outlined,
                onTap: _openCellsDetail,
              ),
              StatCard(
                label: 'Membros',
                value: '$totalMembers',
                icon: Icons.group_outlined,
                onTap: _openMembersDetail,
              ),
              StatCard(
                label: 'Visitantes',
                value: '$totalVisitors',
                icon: Icons.people_outline,
                onTap: _openVisitorsDetail,
              ),
              StatCard(
                label: 'Integrados',
                value: '$integrated',
                icon: Icons.check_circle_outline,
                subtitle: totalVisitors > 0
                    ? '${(integrated / totalVisitors * 100).round()}%'
                    : null,
                onTap: _openIntegratedDetail,
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Ações rápidas ────────────────────────────────────────────
          AppSectionHeader(title: 'Ações rápidas'),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: AppSpacing.buttonHeightMd,
                  child: FilledButton.icon(
                    onPressed: _contacts.isEmpty ? null : _openWhatsappSheet,
                    icon: const Icon(Icons.chat_outlined, size: 18),
                    label: const Text('Enviar WhatsApp'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.whatsapp,
                      foregroundColor: AppColors.white,
                      textStyle: AppTypography.buttonLabel,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: SizedBox(
                  height: AppSpacing.buttonHeightMd,
                  child: OutlinedButton.icon(
                    onPressed: widget.cells.isEmpty
                        ? null
                        : () => widget.onOpenCell(widget.cells.first, tab: 2),
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Registrar presença'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Minhas células ───────────────────────────────────────────
          AppSectionHeader(title: 'Minhas células (${widget.cells.length})'),
          const SizedBox(height: AppSpacing.sm),
          ...widget.cells.map(
            (cell) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: AppCard(
                onTap: () => widget.onOpenCell(cell),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                      child: Icon(
                        Icons.groups_2_outlined,
                        size: 22,
                        color: theme.brightness == Brightness.dark
                            ? AppColors.linkDark
                            : AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cell.name, style: AppTypography.titleSmall),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (cell.typeName != null) cell.typeName!,
                              '${cell.dayLabel} ${cell.time}',
                            ].join(' · '),
                            style: AppTypography.bodySmall.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '${_memberCount[cell.id] ?? 0} membros',
                          style: AppTypography.labelMedium.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        Text(
                          '${_visitorCount[cell.id] ?? 0} visitantes',
                          style: AppTypography.labelSmall.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Icon(
                      Icons.chevron_right,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),

          // ── Visitantes recentes ──────────────────────────────────────
          AppSectionHeader(title: 'Visitantes recentes'),
          const SizedBox(height: AppSpacing.sm),
          if (_recentVisitors.isEmpty)
            AppCard(
              child: Text(
                'Nenhum visitante encaminhado ainda.',
                style: AppTypography.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ..._recentVisitors.map(
              (v) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      AppAvatar(initials: v.initials),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(v.name, style: AppTypography.titleSmall),
                            const SizedBox(height: 2),
                            Text(
                              v.cellName,
                              style: AppTypography.bodySmall.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      VisitorStatusBadge(status: v.status ?? 'novo'),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.xl2),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// WhatsApp — envio restrito às células do líder
// ═════════════════════════════════════════════════════════════════════════════

class _LeaderWhatsappSheet extends StatefulWidget {
  const _LeaderWhatsappSheet({required this.cells, required this.contacts});

  final List<LeaderCellInfo> cells;
  final List<_Contact> contacts;

  @override
  State<_LeaderWhatsappSheet> createState() => _LeaderWhatsappSheetState();
}

class _LeaderWhatsappSheetState extends State<_LeaderWhatsappSheet> {
  String? _cellFilter; // null = todas
  int _typeFilter = 0; // 0 todos · 1 visitantes · 2 membros
  final _msgCtrl = TextEditingController();
  final Set<String> _selectedKeys = {};
  bool _sending = false;
  int _sentCount = 0;

  static const _typeLabels = ['Todos', 'Visitantes', 'Membros'];

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  String _keyOf(_Contact c) => '${c.isMember ? 'm' : 'v'}-${c.id}';

  List<_Contact> get _filtered => widget.contacts.where((c) {
    if (_cellFilter != null && c.cellId != _cellFilter) return false;
    if (_typeFilter == 1 && c.isMember) return false;
    if (_typeFilter == 2 && !c.isMember) return false;
    return true;
  }).toList();

  List<_Contact> get _selected =>
      widget.contacts.where((c) => _selectedKeys.contains(_keyOf(c))).toList();

  void _insertVariable(String variable) {
    final sel = _msgCtrl.selection;
    final text = _msgCtrl.text;
    final start = sel.start < 0 ? text.length : sel.start;
    final end = sel.end < 0 ? text.length : sel.end;
    _msgCtrl.value = TextEditingValue(
      text: text.replaceRange(start, end, variable),
      selection: TextSelection.collapsed(offset: start + variable.length),
    );
    setState(() {});
  }

  String _personalise(String message, _Contact c) => message
      .replaceAll('{nome}', c.name.split(' ').first)
      .replaceAll('{celula}', c.cellName);

  String _normalisePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return '';
    if (digits.startsWith('55') && digits.length >= 12) return digits;
    if (digits.length == 11 || digits.length == 10) return '55$digits';
    return digits;
  }

  Future<void> _send() async {
    final recipients = _selected;
    final message = _msgCtrl.text.trim();
    if (recipients.isEmpty || message.isEmpty) return;

    setState(() {
      _sending = true;
      _sentCount = 0;
    });

    for (final r in recipients) {
      final phone = _normalisePhone(r.phone);
      if (phone.isEmpty) continue;
      final uri = Uri.parse(
        'https://wa.me/$phone?text=${Uri.encodeComponent(_personalise(message, r))}',
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        await Future<void>.delayed(const Duration(milliseconds: 600));
      }
      if (!mounted) return;
      setState(() => _sentCount++);
    }

    if (!mounted) return;
    setState(() => _sending = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        content: Text(
          '$_sentCount de ${recipients.length} mensagens abertas no WhatsApp.',
        ),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filtered;
    final allSelected =
        filtered.isNotEmpty &&
        filtered.every((c) => _selectedKeys.contains(_keyOf(c)));

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePaddingH,
              AppSpacing.sm,
              AppSpacing.sm,
              0,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.chat_outlined,
                  color: AppColors.whatsapp,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Enviar WhatsApp',
                    style: AppTypography.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Fechar',
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
              children: [
                // ── Filtro por célula (somente as células do líder) ────
                if (widget.cells.length > 1) ...[
                  Text(
                    'CÉLULA',
                    style: AppTypography.sectionLabel.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        FilterChip(
                          label: const Text('Todas'),
                          selected: _cellFilter == null,
                          showCheckmark: false,
                          onSelected: (_) => setState(() => _cellFilter = null),
                        ),
                        for (final cell in widget.cells) ...[
                          const SizedBox(width: AppSpacing.sm),
                          FilterChip(
                            label: Text(cell.name),
                            selected: _cellFilter == cell.id,
                            showCheckmark: false,
                            onSelected: (_) =>
                                setState(() => _cellFilter = cell.id),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),
                ],

                // ── Filtro por tipo ────────────────────────────────────
                Row(
                  children: [
                    for (var i = 0; i < _typeLabels.length; i++) ...[
                      if (i > 0) const SizedBox(width: AppSpacing.sm),
                      FilterChip(
                        label: Text(_typeLabels[i]),
                        selected: _typeFilter == i,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _typeFilter = i),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.base),

                // ── Destinatários ──────────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Destinatários (${_selected.length} selecionados)',
                        style: AppTypography.titleSmall,
                      ),
                    ),
                    TextButton(
                      onPressed: filtered.isEmpty
                          ? null
                          : () => setState(() {
                              if (allSelected) {
                                for (final c in filtered) {
                                  _selectedKeys.remove(_keyOf(c));
                                }
                              } else {
                                for (final c in filtered) {
                                  _selectedKeys.add(_keyOf(c));
                                }
                              }
                            }),
                      child: Text(
                        allSelected ? 'Limpar seleção' : 'Selecionar todos',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                if (filtered.isEmpty)
                  AppCard(
                    child: Text(
                      'Nenhum contato neste filtro.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < filtered.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          CheckboxListTile(
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _selectedKeys.contains(_keyOf(filtered[i])),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _selectedKeys.add(_keyOf(filtered[i]));
                              } else {
                                _selectedKeys.remove(_keyOf(filtered[i]));
                              }
                            }),
                            title: Text(
                              filtered[i].name,
                              style: AppTypography.bodyMedium,
                            ),
                            subtitle: Text(
                              '${filtered[i].isMember ? 'Membro' : 'Visitante'} · ${filtered[i].cellName}'
                              '${filtered[i].phone.isEmpty ? ' · sem telefone' : ''}',
                              style: AppTypography.labelSmall.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpacing.base),

                // ── Mensagem ───────────────────────────────────────────
                Text('Mensagem', style: AppTypography.titleSmall),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    for (final v in const ['{nome}', '{celula}'])
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 14),
                        label: Text(v),
                        onPressed: () => _insertVariable(v),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _msgCtrl,
                  maxLines: 5,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText:
                        'Olá {nome}! Nossa célula {celula} se reúne essa semana…',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  height: AppSpacing.buttonHeightLg,
                  child: FilledButton.icon(
                    onPressed:
                        _sending ||
                            _selected.isEmpty ||
                            _msgCtrl.text.trim().isEmpty
                        ? null
                        : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.white,
                            ),
                          )
                        : const Icon(Icons.send_outlined, size: 18),
                    label: Text(
                      _sending
                          ? 'Enviando ($_sentCount/${_selected.length})…'
                          : 'Enviar para ${_selected.length} contato(s)',
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.whatsapp,
                      foregroundColor: AppColors.white,
                      textStyle: AppTypography.buttonLabel,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusMd,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
