import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'dart:developer' as developer;
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/address_selector.dart';
import '../../../../shared/widgets/cep_address_fields.dart';
import '../../data/report_export_service.dart';

import '../utils/snackbar_helper.dart';
import '../widgets/chart_legend.dart';
import '../widgets/demographic_fields.dart';
import '../widgets/demographics_section.dart';
import '../widgets/detail_row.dart';
import '../widgets/monthly_bar_chart.dart';
import '../widgets/visitor_details_sheet.dart';
import '../widgets/visitor_widgets.dart';
import '../../../leader/presentation/widgets/attendance_calendar_dialog.dart';
import '../../../leader/presentation/widgets/attendee_widgets.dart';
import 'chart_detail_page.dart';
import 'admin_dashboard_sheets.dart';
import 'dashboard_tab.dart';
import 'more_menu_tab.dart';
import 'report_metric_detail_page.dart';
import '../widgets/admin_scaffold.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../injection/injection.dart';

// Alias para retrocompatibilidade com código legado no arquivo
void _showTopSnackBar(
  BuildContext context,
  String message, {
  Color backgroundColor = AppColors.error,
}) => showDashboardSnackBar(context, message, backgroundColor: backgroundColor);

/// Admin Dashboard — RF12
/// Multi-tab interface: Início, Visitantes, Células, Relatórios (+ Mais no mobile).
/// No desktop o shell (sidebar navy) é provido por [AdminScaffold] via router.
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key, this.initialTab = 0});

  /// Aba inicial (vinda da query `?tab=` — usada pela sidebar desktop).
  final int initialTab;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  late int _selectedIndex = widget.initialTab.clamp(0, 4);

  static const _tabTitles = [
    'Visão geral',
    'Visitantes',
    'Células',
    'Relatórios',
    'Mais',
  ];

  void _switchTab(int i) {
    if (AdminScaffold.isDesktop(context)) {
      // Mantém a URL em sincronia com a sidebar.
      context.go('${AppRoutes.adminDashboard}?tab=$i');
    } else {
      setState(() => _selectedIndex = i);
    }
  }

  void _openNewVisitor() async {
    final dio = getIt<DioClient>().dio;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => NewVisitorSheet(dio: dio),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = AdminScaffold.isDesktop(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final appBar = AppBar(
      automaticallyImplyLeading: false,
      title: Text(_tabTitles[_selectedIndex]),
      actions: [
        if (isDesktop && _selectedIndex != 4) ...[
          SizedBox(
            height: 42,
            child: FilledButton.icon(
              onPressed: _openNewVisitor,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Novo visitante'),
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: AppColors.white,
                textStyle: AppTypography.buttonLabel,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
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
        const SizedBox(width: AppSpacing.sm),
      ],
    );

    final tabContent = IndexedStack(
      index: _selectedIndex,
      children: [
        DashboardTab(onSwitchTab: _switchTab),
        const _VisitorsAdminTab(),
        const _CellsAdminTab(),
        const _ReportsTab(),
        const MoreMenuTab(),
      ],
    );

    if (isDesktop) {
      // Sidebar fica no AdminScaffold; aqui só topbar + conteúdo.
      return Scaffold(appBar: appBar, body: tabContent);
    }

    return Scaffold(
      appBar: appBar,
      body: tabContent,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: const [
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
            icon: Icon(Icons.groups_2_outlined),
            selectedIcon: Icon(Icons.groups_2),
            label: 'Células',
          ),
          NavigationDestination(
            icon: Icon(Icons.insert_chart_outlined_rounded),
            selectedIcon: Icon(Icons.insert_chart_rounded),
            label: 'Relatórios',
          ),
          NavigationDestination(
            icon: Icon(Icons.more_horiz),
            selectedIcon: Icon(Icons.more_horiz),
            label: 'Mais',
          ),
        ],
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
  List<Map<String, dynamic>> _bairros = [];

  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedBairroId;
  String? _selectedEstadoCivil;
  bool? _isBaptized;
  bool? _frequentacelula;
  String? _selectedAgeRange;
  String? _statusFilter;
  Map<String, dynamic>? _selectedVisitor; // painel de detalhe (desktop)

  static const _statusFilters = [
    (null, 'Todos'),
    (AppConstants.statusNew, 'Novo'),
    (AppConstants.statusFollowing, 'Em acompanhamento'),
    (AppConstants.statusIntegrated, 'Integrado'),
    (AppConstants.statusInactive, 'Não retornou'),
  ];

  static const _ageRanges = [
    '18-25',
    '26-35',
    '36-45',
    '46-55',
    '56-65',
    '65+',
  ];
  static const _maritalStatuses = ['solteiro', 'casado', 'divorciado', 'viuvo'];

  @override
  void initState() {
    super.initState();
    _dio = getIt<DioClient>().dio;
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([_loadBairros(), _loadVisitors()]);
  }

  Future<void> _loadBairros() async {
    try {
      // Por enquanto não carrega bairros dinamicamente
      // Você pode expandir para carregar por cidade se necessário
      if (mounted) {
        setState(() {
          _bairros = [];
        });
      }
    } catch (e) {
      developer.log('Erro ao carregar bairros: $e');
    }
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _query.toLowerCase();
    var filtered = _visitors;

    // Filtro por nome/search
    if (q.isNotEmpty) {
      filtered = filtered
          .where((v) => (v['name'] as String).toLowerCase().contains(q))
          .toList();
    }

    // Filtro por status (pills)
    if (_statusFilter != null) {
      filtered = filtered
          .where((v) => (v['status'] as String? ?? 'novo') == _statusFilter)
          .toList();
    }

    // Filtro por bairro
    if (_selectedBairroId != null) {
      filtered = filtered
          .where((v) => v['bairroId'] == _selectedBairroId)
          .toList();
    }

    // Filtro por estado civil
    if (_selectedEstadoCivil != null) {
      filtered = filtered
          .where(
            (v) =>
                (v['maritalStatus'] as String?)?.toLowerCase().contains(
                  _selectedEstadoCivil!.toLowerCase(),
                ) ??
                false,
          )
          .toList();
    }

    // Filtro por batizados
    if (_isBaptized != null) {
      filtered = filtered
          .where((v) => (v['isBaptized'] as bool?) == _isBaptized)
          .toList();
    }

    // Filtro por frequência em célula
    if (_frequentacelula != null) {
      if (_frequentacelula!) {
        filtered = filtered.where((v) => v['cellId'] != null).toList();
      } else {
        filtered = filtered.where((v) => v['cellId'] == null).toList();
      }
    }

    // Filtro por faixa etária
    if (_selectedAgeRange != null) {
      filtered = filtered.where((v) {
        final birthDate = v['birthDate'] != null
            ? DateTime.tryParse(v['birthDate'] as String)
            : null;
        if (birthDate == null) return false;
        final age = DateTime.now().difference(birthDate).inDays ~/ 365;
        return _isInAgeRange(age, _selectedAgeRange!);
      }).toList();
    }

    return filtered;
  }

  bool _isInAgeRange(int age, String range) {
    final parts = range.split('-');
    final min = int.tryParse(parts[0]) ?? 0;
    final max = parts.length > 1 && parts[1] != '+'
        ? int.tryParse(parts[1]) ?? 100
        : 150;
    return age >= min && age <= max;
  }

  void _openNewVisitorSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => NewVisitorSheet(dio: _dio),
    );
    if (created == true) _loadVisitors();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    final theme = Theme.of(context);

    final list = Stack(
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
                onRefresh: _loadData,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePaddingH,
                    AppSpacing.pagePaddingH,
                    AppSpacing.pagePaddingH,
                    88,
                  ),
                  children: [
                    // ── Search ──────────────────────────────────
                    AppSearchField(
                      hint: 'Pesquisar visitante...',
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _query = v),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ── Filtros pill por status ─────────────────
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final (value, label) in _statusFilters) ...[
                            FilterChip(
                              label: Text(label),
                              selected: _statusFilter == value,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  setState(() => _statusFilter = value),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ── Filters ─────────────────────────────────
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Bairro filter
                          Container(
                            constraints: const BoxConstraints(minWidth: 140),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.grey300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: _selectedBairroId,
                                hint: const Text('Bairro'),
                                isDense: true,
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Todos os bairros'),
                                  ),
                                  ..._bairros.map(
                                    (b) => DropdownMenuItem<String?>(
                                      value: b['id'] as String,
                                      child: Text(b['name'] as String),
                                    ),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() => _selectedBairroId = v);
                                  _loadVisitors();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),

                          // Faixa etária filter
                          Container(
                            constraints: const BoxConstraints(minWidth: 130),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.grey300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: _selectedAgeRange,
                                hint: const Text('Faixa etária'),
                                isDense: true,
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Todas'),
                                  ),
                                  ..._ageRanges.map(
                                    (r) => DropdownMenuItem<String?>(
                                      value: r,
                                      child: Text('$r anos'),
                                    ),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() => _selectedAgeRange = v);
                                  _loadVisitors();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),

                          // Estado civil filter
                          Container(
                            constraints: const BoxConstraints(minWidth: 150),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: AppColors.grey300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String?>(
                                value: _selectedEstadoCivil,
                                hint: const Text('Estado civil'),
                                isDense: true,
                                isExpanded: true,
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Todos'),
                                  ),
                                  ..._maritalStatuses.map(
                                    (s) => DropdownMenuItem<String?>(
                                      value: s,
                                      child: Text(s),
                                    ),
                                  ),
                                ],
                                onChanged: (v) {
                                  setState(() => _selectedEstadoCivil = v);
                                  _loadVisitors();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),

                          // Batizados filter
                          FilterChip(
                            label: const Text('Batizados'),
                            selected: _isBaptized == true,
                            onSelected: (v) => setState(() {
                              _isBaptized = v ? true : null;
                              _loadVisitors();
                            }),
                          ),
                          const SizedBox(width: AppSpacing.sm),

                          // Frequenta célula filter
                          FilterChip(
                            label: const Text('Frequ. Célula'),
                            selected: _frequentacelula == true,
                            onSelected: (v) => setState(() {
                              _frequentacelula = v ? true : null;
                              _loadVisitors();
                            }),
                          ),
                          const SizedBox(width: AppSpacing.sm),

                          // Limpar filtros
                          if (_selectedBairroId != null ||
                              _selectedAgeRange != null ||
                              _selectedEstadoCivil != null ||
                              _isBaptized != null ||
                              _frequentacelula != null)
                            AppButton(
                              label: 'Limpar filtros',
                              variant: AppButtonVariant.outline,
                              onPressed: () => setState(() {
                                _selectedBairroId = null;
                                _selectedAgeRange = null;
                                _selectedEstadoCivil = null;
                                _isBaptized = null;
                                _frequentacelula = null;
                                _loadVisitors();
                              }),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSpacing.base),
                    AppSectionHeader(
                      title:
                          'Visitantes (${_filtered.length}/${_visitors.length})',
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
                        (v) => VisitorAdminTile(
                          name: v['name'] as String,
                          status: v['status'] as String? ?? 'novo',
                          time: _relativeTime(v['createdAt'] as String),
                          birthDate: v['birthDate'] != null
                              ? DateTime.tryParse(v['birthDate'] as String)
                              : null,
                          phone: v['phone'] as String?,
                          email: v['email'] as String?,
                          onTap: () => _openVisitorDetails(v['id'] as String),
                        ),
                      ),
                  ],
                ),
              ),
        if (!isDesktop)
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

    if (!isDesktop || _selectedVisitor == null) return list;

    // Desktop: lista + painel de detalhe fixo à direita (340px).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: list),
        Container(
          width: AppSpacing.detailPanelWidth,
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              left: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.base,
                  AppSpacing.sm,
                  AppSpacing.sm,
                  0,
                ),
                child: Row(
                  children: [
                    Text('Detalhes', style: AppTypography.titleSmall),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Fechar',
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => setState(() => _selectedVisitor = null),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: VisitorDetailsSheet(
                  visitor: _selectedVisitor!,
                  panel: true,
                  onChanged: _loadVisitors,
                ),
              ),
            ],
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
    final isDesktop = MediaQuery.sizeOf(context).width >= 1024;
    try {
      final resp = await _dio.get('/visitors/$visitorId');
      final visitor =
          (resp.data as Map<String, dynamic>)['visitor']
              as Map<String, dynamic>;
      if (!mounted) return;
      if (isDesktop) {
        // Painel de detalhe fixo à direita (340px).
        setState(() => _selectedVisitor = visitor);
        return;
      }
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) =>
            VisitorDetailsSheet(visitor: visitor, onChanged: _loadVisitors),
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
    _dio = getIt<DioClient>().dio;
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

  Widget _buildCellCard(Map<String, dynamic> c) {
    final id = c['id'] as String;
    final name = c['name'] as String;
    final leader = c['leaderName'] as String? ?? '—';
    final day =
        _dayLabels[c['dayOfWeek'] as String] ?? c['dayOfWeek'] as String;
    final members = '${c['currentCount']}/${c['maxCapacity']}';
    final address = (c['address'] as String?) ?? 'Não informado';
    final supervisorName = c['supervisorName'] as String?;
    final coordenacaoName = c['coordenacaoName'] as String?;
    final coordenacaoColor = c['coordenacaoColor'] as String?;
    return _CellAdminCard(
      id: id,
      name: name,
      leader: leader,
      day: day,
      members: members,
      address: address,
      supervisorName: supervisorName,
      coordenacaoName: coordenacaoName,
      coordenacaoColor: coordenacaoColor,
      onTap: () async {
        final changed = await Navigator.of(context).push<bool>(
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
                      // Grid 3 colunas no desktop, lista no mobile.
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns = constraints.maxWidth >= 1100
                              ? 3
                              : constraints.maxWidth >= 720
                              ? 2
                              : 1;
                          final cards = _filtered.map(_buildCellCard).toList();
                          if (columns == 1) return Column(children: cards);
                          return GridView.custom(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: columns,
                                  crossAxisSpacing: AppSpacing.base,
                                  mainAxisSpacing: AppSpacing.xs,
                                  // +16 para a linha de coordenação/supervisor.
                                  mainAxisExtent: 112,
                                ),
                            childrenDelegate: SliverChildListDelegate(cards),
                          );
                        },
                      ),
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
                builder: (_) => NewCellSheet(dio: _dio),
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

/// Cor de uma coordenação (hex do backend). Cinza neutro quando ausente —
/// nem toda célula tem líder→supervisor→coordenação completo na cadeia.
Color _parseHexColor(String? hex) {
  if (hex == null) return AppColors.textSecondary;
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return AppColors.textSecondary;
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
    this.supervisorName,
    this.coordenacaoName,
    this.coordenacaoColor,
  });

  final String id;
  final String name;
  final String leader;
  final String day;
  final String members;
  final String address;
  final VoidCallback onTap;
  final String? supervisorName;
  final String? coordenacaoName;
  final String? coordenacaoColor;

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
                Text(
                  name,
                  style: AppTypography.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '$leader · $day',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs2),
                if (coordenacaoName != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _parseHexColor(coordenacaoColor),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Flexible(
                        child: Text(
                          supervisorName != null
                              ? '$coordenacaoName · $supervisorName'
                              : coordenacaoName!,
                          style: AppTypography.labelSmall.copyWith(
                            color: _parseHexColor(coordenacaoColor),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    'Sem coordenação',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.grey400,
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
  Map<String, dynamic> _demographics = {};
  bool _exportingPdf = false;
  bool _exportingExcel = false;

  static const _exportService = ReportExportService();

  void _openMetricDetail(ReportMetric metric, String headerValue) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ReportMetricDetailPage(metric: metric, headerValue: headerValue),
      ),
    );
  }

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
      final results = await Future.wait([
        _dio.get('/dashboard/stats'),
        _dio.get('/dashboard/monthly-stats'),
        _dio.get('/dashboard/demographics'),
      ]);
      if (!mounted) return;
      setState(() {
        _stats =
            (results[0].data as Map<String, dynamic>)['stats']
                as Map<String, dynamic>;
        _months = ((results[1].data as Map<String, dynamic>)['months'] as List)
            .cast<Map<String, dynamic>>();
        _demographics =
            (results[2].data as Map<String, dynamic>)['demographics']
                as Map<String, dynamic>;
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
                onTap: () => _openMetricDetail(
                  ReportMetric.integrationRate,
                  integrationRate,
                ),
              ),
              StatCard(
                label: 'Líderes Ativos',
                value: '$leaders',
                icon: Icons.people,
                color: AppColors.primary,
                onTap: () =>
                    _openMetricDetail(ReportMetric.activeLeaders, '$leaders'),
              ),
              StatCard(
                label: 'Visitantes (mês)',
                value: '$newThisMonth',
                icon: Icons.calendar_month_outlined,
                color: AppColors.accent,
                onTap: () => _openMetricDetail(
                  ReportMetric.visitorsMonth,
                  '$newThisMonth',
                ),
              ),
              StatCard(
                label: 'Média Frequência',
                value: '${avgAttendance.toStringAsFixed(1)}%',
                icon: Icons.bar_chart,
                color: AppColors.secondary,
                onTap: () => _openMetricDetail(
                  ReportMetric.avgAttendance,
                  '${avgAttendance.toStringAsFixed(1)}%',
                ),
              ),
            ]),
          ),

          const SizedBox(height: AppSpacing.xl),

          DemographicsSection(demographics: _demographics),

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
                      TappableChart(
                        detailTitle: 'Visitantes por Mês',
                        detailSubtitle: 'Últimos 6 meses — total vs integrados',
                        detailChart: DetailBarChart(months: _months),
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
                        child: MonthlyBarChart(months: _months),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          ChartLegend(color: AppColors.primary, label: 'Total'),
                          const SizedBox(width: AppSpacing.base),
                          ChartLegend(
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
            label: _exportingPdf ? 'Gerando PDF...' : 'Exportar em PDF',
            variant: AppButtonVariant.outline,
            prefixIcon: Icons.picture_as_pdf_outlined,
            onPressed: _exportingPdf
                ? null
                : () async {
                    setState(() => _exportingPdf = true);
                    try {
                      await _exportService.exportPdf(
                        stats: _stats,
                        months: _months,
                      );
                    } catch (e) {
                      if (!mounted) return;
                      _showTopSnackBar(context, 'Erro ao gerar PDF: $e');
                    } finally {
                      if (mounted) setState(() => _exportingPdf = false);
                    }
                  },
          ),
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: _exportingExcel ? 'Gerando Excel...' : 'Exportar em Excel',
            variant: AppButtonVariant.outline,
            prefixIcon: Icons.table_chart_outlined,
            onPressed: _exportingExcel
                ? null
                : () async {
                    setState(() => _exportingExcel = true);
                    try {
                      await _exportService.exportExcel(
                        stats: _stats,
                        months: _months,
                      );
                    } catch (e) {
                      if (!mounted) return;
                      _showTopSnackBar(context, 'Erro ao gerar Excel: $e');
                    } finally {
                      if (mounted) setState(() => _exportingExcel = false);
                    }
                  },
          ),

          const SizedBox(height: AppSpacing.xl2),
        ],
      ),
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
  List<CellAttendee> _attendees = [];
  List<CellMeetingSummary> _meetings = [];

  final _searchCtrl = TextEditingController();
  String _query = '';
  AttendeeFilter _filter = AttendeeFilter.all;

  @override
  void initState() {
    super.initState();
    _dio = getIt<DioClient>().dio;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _dio.get('/cells/${widget.id}'),
        _dio.get('/attendance/cell/${widget.id}/attendees'),
        _dio.get('/attendance/cell/${widget.id}/meetings'),
      ]);
      final cell =
          (results[0].data as Map<String, dynamic>)['cell']
              as Map<String, dynamic>;
      final attendeesRaw =
          (results[1].data as Map<String, dynamic>)['attendees'] as List? ?? [];
      final meetingsRaw =
          (results[2].data as Map<String, dynamic>)['meetings'] as List? ?? [];

      if (!mounted) return;
      setState(() {
        _cell = cell;
        _attendees = attendeesRaw
            .map((e) => CellAttendee.fromJson(e as Map<String, dynamic>))
            .toList();
        _meetings = meetingsRaw
            .map((e) => CellMeetingSummary.fromJson(e as Map<String, dynamic>))
            .toList();
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

  List<CellAttendee> get _filteredAttendees {
    final q = _query.trim().toLowerCase();
    return _attendees.where((a) {
      if (!_filter.matches(a)) return false;
      if (q.isEmpty) return true;
      return a.name.toLowerCase().contains(q) ||
          (a.phone ?? '').contains(q) ||
          (a.email ?? '').toLowerCase().contains(q);
    }).toList();
  }

  int _countFor(AttendeeFilter filter) =>
      _attendees.where(filter.matches).length;

  Future<void> _openAttendeeDetails(CellAttendee attendee) async {
    if (attendee.isMember) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _CellMemberDetailSheet(member: attendee),
      );
      return;
    }
    try {
      final resp = await _dio.get('/visitors/${attendee.id}');
      final visitor =
          (resp.data as Map<String, dynamic>)['visitor']
              as Map<String, dynamic>;
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => VisitorDetailsSheet(visitor: visitor),
      );
      _load();
    } on DioException catch (e) {
      if (!mounted) return;
      _showTopSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao abrir visitante',
      );
    }
  }

  /// Duas origens de cadastro (visitante e membro) atrás de um único botão —
  /// mesmo padrão da aba Frequentadores do líder.
  Future<void> _showAddOptions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            ListTile(
              leading: const Icon(Icons.person_add_outlined),
              title: const Text('Novo visitante'),
              subtitle: const Text('Entra no funil de acompanhamento'),
              onTap: () => Navigator.of(ctx).pop('visitor'),
            ),
            ListTile(
              leading: const Icon(Icons.group_add_outlined),
              title: const Text('Adicionar membro'),
              subtitle: const Text('Já faz parte da célula'),
              onTap: () => Navigator.of(ctx).pop('member'),
            ),
            const SizedBox(height: AppSpacing.base),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => action == 'visitor'
          ? NewVisitorSheet(dio: _dio, cellId: widget.id)
          : _AddCellMemberSheet(dio: _dio, cellId: widget.id),
    );
    if (created == true) _load();
  }

  /// Trocar o líder também troca coordenação/supervisor exibidos, já que os
  /// dois são derivados do líder — não precisa de nenhuma ação extra pra isso,
  /// só recarregar a célula depois da troca.
  Future<void> _changeLeader() async {
    final currentLeaderId = _cell?['leaderId'] as String?;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ChangeLeaderSheet(
        dio: _dio,
        cellId: widget.id,
        currentLeaderId: currentLeaderId,
      ),
    );
    if (changed == true) _load();
  }

  /// Coordenação não é um campo da célula: é derivada de líder → supervisor →
  /// coordenação. "Alterar" aqui significa reatribuir o supervisor do líder —
  /// a coordenação exibida segue automaticamente.
  Future<void> _changeSupervisor() async {
    final leaderId = _cell?['leaderId'] as String?;
    if (leaderId == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ChangeSupervisorSheet(
        dio: _dio,
        leaderId: leaderId,
        currentSupervisorId: _cell?['leaderSupervisorId'] as String?,
      ),
    );
    if (changed == true) _load();
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

  Future<void> _toggleActive(bool value) async {
    if (!value) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Desativar célula'),
          content: const Text(
            'Uma célula inativa some das listas de frequentadores e do '
            'cadastro público. Deseja continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                'Desativar',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    if (!mounted) return;
    setState(() => _isActive = value);
    _showTopSnackBar(
      context,
      value ? 'Célula ativada' : 'Célula desativada',
      backgroundColor: AppColors.success,
    );
  }

  Future<void> _openAddressMap(String address) async {
    final lat = (_cell?['latitude'] as num?)?.toDouble();
    final lng = (_cell?['longitude'] as num?)?.toDouble();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddressMapSheet(
        title: (_cell?['name'] as String?) ?? widget.name,
        address: address,
        latitude: lat,
        longitude: lng,
      ),
    );
  }

  Future<void> _showAllMeetings() {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Padding(
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
              const SizedBox(height: AppSpacing.base),
              Text('Reuniões da célula', style: AppTypography.headlineSmall),
              const SizedBox(height: AppSpacing.base),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  itemCount: _meetings.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final m = _meetings[i];
                    return AppCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  formatDateBr(m.meetingDate.toLocal()),
                                  style: AppTypography.titleSmall,
                                ),
                                if (m.lesson != null)
                                  Text(
                                    m.lesson!,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          AppBadge(
                            label: m.isRecorded ? 'Realizada' : 'Pendente',
                            variant: m.isRecorded
                                ? AppBadgeVariant.success
                                : AppBadgeVariant.warning,
                            size: AppBadgeSize.sm,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalhes da Célula')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalhes da Célula')),
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
    final leaderName = (cell['leaderName'] as String?) ?? widget.leader;
    final supervisorName = cell['supervisorName'] as String?;
    final coordenacaoName = cell['coordenacaoName'] as String?;
    final coordenacaoColor = cell['coordenacaoColor'] as String?;
    final day = (cell['dayOfWeek'] as String?) ?? widget.day;
    final time = (cell['time'] as String?) ?? '';
    final address = (cell['address'] as String?) ?? widget.address;
    final membersLabel = '${_attendees.length}/${(cell['maxCapacity'] ?? '—')}';

    final meetingsCard = LastMeetingsCard(
      meetings: _meetings,
      onSeeAll: _showAllMeetings,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes da Célula'),
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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOptions,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Adicionar'),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final header = AppCard(
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
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Líder: $leaderName',
                        style: AppTypography.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AppButton(
                      label: 'Alterar',
                      variant: AppButtonVariant.ghost,
                      size: AppButtonSize.sm,
                      isFullWidth: false,
                      onPressed: _changeLeader,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    if (coordenacaoName != null) ...[
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _parseHexColor(coordenacaoColor),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          supervisorName != null
                              ? '$coordenacaoName · Supervisor: $supervisorName'
                              : coordenacaoName,
                          style: AppTypography.bodyMedium.copyWith(
                            color: _parseHexColor(coordenacaoColor),
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ] else
                      Expanded(
                        child: Text(
                          'Sem coordenação vinculada',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.grey400,
                          ),
                        ),
                      ),
                    AppButton(
                      label: 'Alterar',
                      variant: AppButtonVariant.ghost,
                      size: AppButtonSize.sm,
                      isFullWidth: false,
                      onPressed: _changeSupervisor,
                    ),
                  ],
                ),
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
                const SizedBox(height: AppSpacing.xs),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Célula ativa'),
                  value: _isActive,
                  onChanged: _toggleActive,
                ),
              ],
            ),
          );

          final filtered = _filteredAttendees;
          final listSection = <Widget>[
            header,
            const SizedBox(height: AppSpacing.xl),
            AppSearchField(
              hint: 'Pesquisar por nome, telefone ou e-mail...',
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: AppSpacing.base),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final filter in AttendeeFilter.values)
                  FilterChip(
                    label: Text('${filter.label} (${_countFor(filter)})'),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.base),
            AppSectionHeader(title: 'Frequentadores (${filtered.length})'),
            const SizedBox(height: AppSpacing.sm),
            if (filtered.isEmpty)
              AppEmptyState(
                title: _query.isNotEmpty || _filter != AttendeeFilter.all
                    ? 'Nada encontrado'
                    : 'Ninguém na célula ainda',
                subtitle: _query.isNotEmpty || _filter != AttendeeFilter.all
                    ? 'Ajuste a busca ou o filtro.'
                    : 'Cadastre um visitante ou adicione um membro pelo botão abaixo.',
                icon: Icons.groups_outlined,
              )
            else
              for (final attendee in filtered) ...[
                AttendeeCard(
                  attendee: attendee,
                  onTap: () => _openAttendeeDetails(attendee),
                  onFrequencyTap: () => showAttendanceCalendarDialog(
                    context: context,
                    dio: _dio,
                    cellId: widget.id,
                    attendee: attendee,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
          ];

          final isWide = constraints.maxWidth >= 1000;
          if (!isWide) {
            return RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
                children: [
                  ...listSection,
                  const SizedBox(height: AppSpacing.xl),
                  meetingsCard,
                  const SizedBox(height: AppSpacing.xl2),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _load,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
                    children: [
                      ...listSection,
                      const SizedBox(height: AppSpacing.xl2),
                    ],
                  ),
                ),
                SizedBox(
                  width: 360,
                  child: ListView(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.pagePaddingH,
                      right: AppSpacing.pagePaddingH,
                      bottom: AppSpacing.xl2,
                    ),
                    children: [meetingsCard],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Detalhes de um membro de célula, no mesmo padrão visual das outras fichas
/// do admin (`VisitorDetailsSheet`): avatar + nome + badge, depois seções com
/// `DetailRow`. Endereço não é clicável aqui, igual à ficha de visitante.
class _CellMemberDetailSheet extends StatelessWidget {
  const _CellMemberDetailSheet({required this.member});

  final CellAttendee member;

  static String _textOrDash(String? v) =>
      (v == null || v.isEmpty) ? 'Não informado' : v;

  String get _genderLabel => switch (member.gender) {
    'MASCULINO' => 'Masculino',
    'FEMININO' => 'Feminino',
    _ => 'Não informado',
  };

  @override
  Widget build(BuildContext context) {
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
                  AppAvatar(initials: member.initials, size: 56),
                  const SizedBox(width: AppSpacing.base),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.name, style: AppTypography.headlineSmall),
                        const SizedBox(height: AppSpacing.xs),
                        const AppBadge(
                          label: 'Membro',
                          variant: AppBadgeVariant.success,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Frequência', style: AppTypography.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                padding: EdgeInsets.zero,
                child: DetailRow(
                  icon: Icons.insights_outlined,
                  label: 'Presença nos encontros',
                  value: member.meetingsCount == 0
                      ? 'Sem presença registrada'
                      : '${formatPercentBr(member.attendanceRate)} '
                            '(${member.presentCount} de ${member.meetingsCount})',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Informações Básicas', style: AppTypography.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    DetailRow(
                      icon: Icons.phone_outlined,
                      label: 'Telefone',
                      value: _textOrDash(member.phone),
                    ),
                    const Divider(height: 1),
                    DetailRow(
                      icon: Icons.email_outlined,
                      label: 'E-mail',
                      value: _textOrDash(member.email),
                    ),
                    const Divider(height: 1),
                    DetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Endereço',
                      value: _textOrDash(member.address),
                    ),
                    const Divider(height: 1),
                    DetailRow(
                      icon: Icons.access_time_outlined,
                      label: 'Membro desde',
                      value: formatDateBr(member.createdAt.toLocal()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text('Informações Pessoais', style: AppTypography.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    DetailRow(
                      icon: Icons.cake_outlined,
                      label: 'Data de Nascimento',
                      value: member.birthDate != null
                          ? formatDateBr(member.birthDate!.toLocal())
                          : 'Não informado',
                    ),
                    const Divider(height: 1),
                    DetailRow(
                      icon: Icons.favorite_outline,
                      label: 'Estado Civil',
                      value: _textOrDash(member.maritalStatus),
                    ),
                    const Divider(height: 1),
                    DetailRow(
                      icon: Icons.wc_outlined,
                      label: 'Gênero',
                      value: _genderLabel,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl2),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reatribui o líder da célula. Uma tela só: busca + lista de líderes, tocar
/// em um já salva. Sem exclusividade — um líder pode ter mais de uma célula,
/// então todos aparecem, mesmo quem já lidera outra.
class _ChangeLeaderSheet extends StatefulWidget {
  const _ChangeLeaderSheet({
    required this.dio,
    required this.cellId,
    this.currentLeaderId,
  });

  final Dio dio;
  final String cellId;
  final String? currentLeaderId;

  @override
  State<_ChangeLeaderSheet> createState() => _ChangeLeaderSheetState();
}

class _ChangeLeaderSheetState extends State<_ChangeLeaderSheet> {
  bool _loading = true;
  String? _error;
  String? _savingId;
  List<Map<String, dynamic>> _leaders = [];
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await widget.dio.get('/users/leaders');
      final leaders = ((resp.data as Map<String, dynamic>)['leaders'] as List)
          .cast<Map<String, dynamic>>();
      if (!mounted) return;
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

  List<Map<String, dynamic>> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _leaders;
    return _leaders
        .where((l) => (l['name'] as String? ?? '').toLowerCase().contains(q))
        .toList();
  }

  Future<void> _assign(String leaderId) async {
    if (leaderId == widget.currentLeaderId) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _savingId = leaderId);
    try {
      await widget.dio.patch(
        '/cells/${widget.cellId}',
        data: {'leaderId': leaderId},
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _savingId = null);
      _showTopSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao atribuir líder',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Padding(
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
            const SizedBox(height: AppSpacing.base),
            Text('Alterar líder', style: AppTypography.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Coordenação e supervisor seguem o novo líder automaticamente.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: Center(
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
              )
            else ...[
              AppSearchField(
                hint: 'Pesquisar líder...',
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ListView(
                  controller: controller,
                  children: [
                    for (final l in _filtered)
                      ListTile(
                        leading: AppAvatar(
                          initials: (l['name'] as String? ?? '?')
                              .split(' ')
                              .where((e) => e.isNotEmpty)
                              .map((e) => e[0])
                              .take(2)
                              .join(),
                        ),
                        title: Text(l['name'] as String? ?? 'Sem nome'),
                        subtitle: Text(
                          (l['phone'] as String?)?.isNotEmpty == true
                              ? l['phone'] as String
                              : 'Sem telefone',
                        ),
                        trailing: l['id'] == widget.currentLeaderId
                            ? const Icon(
                                Icons.check_circle,
                                color: AppColors.primary,
                              )
                            : (_savingId == l['id']
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : null),
                        onTap: _savingId != null
                            ? null
                            : () => _assign(l['id'] as String),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Reatribui o supervisor do líder da célula — a coordenação exibida é
/// derivada dele, então não há campo de coordenação separado para editar.
/// Uma tela só: lista de supervisores (com a própria coordenação ao lado),
/// tocar em um já salva.
class _ChangeSupervisorSheet extends StatefulWidget {
  const _ChangeSupervisorSheet({
    required this.dio,
    required this.leaderId,
    this.currentSupervisorId,
  });

  final Dio dio;
  final String leaderId;
  final String? currentSupervisorId;

  @override
  State<_ChangeSupervisorSheet> createState() => _ChangeSupervisorSheetState();
}

class _ChangeSupervisorSheetState extends State<_ChangeSupervisorSheet> {
  bool _loading = true;
  String? _error;
  String? _savingId;
  List<Map<String, dynamic>> _supervisors = [];
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.dio.get('/users/supervisors'),
        widget.dio.get('/coordenacoes'),
      ]);
      final supervisorList =
          ((results[0].data as Map<String, dynamic>)['supervisors'] as List)
              .cast<Map<String, dynamic>>();
      final coordenacaoList =
          ((results[1].data as Map<String, dynamic>)['coordenacoes'] as List)
              .cast<Map<String, dynamic>>();
      final coordenacaoById = {
        for (final c in coordenacaoList) c['id'] as String: c,
      };

      if (!mounted) return;
      setState(() {
        _supervisors = supervisorList.map((s) {
          final coord = coordenacaoById[s['coordenacaoId'] as String?];
          return {
            ...s,
            'coordenacaoName': coord?['name'],
            'coordenacaoColor': coord?['color'],
          };
        }).toList();
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
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _supervisors;
    return _supervisors
        .where((s) => (s['name'] as String? ?? '').toLowerCase().contains(q))
        .toList();
  }

  Future<void> _assign(String? supervisorId) async {
    setState(() => _savingId = supervisorId ?? '');
    try {
      await widget.dio.patch(
        '/users/leaders/${widget.leaderId}/supervisor',
        data: {'supervisorId': supervisorId},
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _savingId = null);
      _showTopSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao atribuir supervisor',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Padding(
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
            const SizedBox(height: AppSpacing.base),
            Text('Alterar supervisor', style: AppTypography.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'A coordenação da célula segue a coordenação do supervisor.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: Center(
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
              )
            else ...[
              AppSearchField(
                hint: 'Pesquisar supervisor...',
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              Expanded(
                child: ListView(
                  controller: controller,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.block_outlined),
                      title: const Text('Sem supervisor'),
                      trailing: widget.currentSupervisorId == null
                          ? const Icon(
                              Icons.check_circle,
                              color: AppColors.primary,
                            )
                          : (_savingId == ''
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : null),
                      onTap: _savingId != null ? null : () => _assign(null),
                    ),
                    const Divider(height: 1),
                    for (final s in _filtered)
                      ListTile(
                        leading: Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: _parseHexColor(
                              s['coordenacaoColor'] as String?,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        title: Text(s['name'] as String? ?? 'Sem nome'),
                        subtitle: Text(
                          s['coordenacaoName'] as String? ?? 'Sem coordenação',
                        ),
                        trailing: s['id'] == widget.currentSupervisorId
                            ? const Icon(
                                Icons.check_circle,
                                color: AppColors.primary,
                              )
                            : (_savingId == s['id']
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : null),
                        onTap: _savingId != null
                            ? null
                            : () => _assign(s['id'] as String),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
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
  CepAddressValue _addressValue = const CepAddressValue(
    address: '',
    numero: '',
    complemento: null,
    bairroId: null,
  );
  String? _gender;
  DateTime? _birthDate;
  String? _maritalStatus;
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
        data: {
          'name': name,
          'phone': phone,
          // CellMember só tem um campo `address` — número/complemento entram
          // concatenados, diferente de Visitor (que tem colunas próprias).
          if (!_addressValue.isEmpty) 'address': _addressValue.combined,
          if (_addressValue.bairroId != null)
            'bairroId': _addressValue.bairroId,
          if (_gender != null) 'gender': _gender,
          if (_birthDate != null) 'birthDate': apiBirthDate(_birthDate),
          if (_maritalStatus != null) 'maritalStatus': _maritalStatus,
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
              CepAddressFields(
                dio: widget.dio,
                onChanged: (v) => setState(() => _addressValue = v),
              ),
              const SizedBox(height: AppSpacing.base),
              DemographicFields(
                gender: _gender,
                birthDate: _birthDate,
                maritalStatus: _maritalStatus,
                onGenderChanged: (v) => setState(() => _gender = v),
                onBirthDateChanged: (v) => setState(() => _birthDate = v),
                onMaritalStatusChanged: (v) =>
                    setState(() => _maritalStatus = v),
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
  late final TextEditingController _timeCtrl;
  final _cepCtrl = TextEditingController();
  String? _bairroId;
  String? _estadoId;
  String? _cidadeId;
  double? _latitude;
  double? _longitude;
  bool _cepLoading = false;
  bool _saving = false;
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(
      text: (widget.cell['name'] as String?) ?? '',
    );
    _addressCtrl = TextEditingController(
      text: (widget.cell['address'] as String?) ?? '',
    );
    _timeCtrl = TextEditingController(
      text: (widget.cell['time'] as String?) ?? '19:00',
    );
    _bairroId = widget.cell['bairroId'] as String?;
    _estadoId = widget.cell['estadoId'] as String?;
    _cidadeId = widget.cell['cidadeId'] as String?;
    _latitude = (widget.cell['latitude'] as num?)?.toDouble();
    _longitude = (widget.cell['longitude'] as num?)?.toDouble();
    _mapController = MapController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _timeCtrl.dispose();
    _cepCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ── CEP lookup ─────────────────────────────────────────────────────────

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

      String? foundEstadoId, foundCidadeId, foundBairroId;
      double? foundLat, foundLng;

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
      final resp = await Dio().get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'format': 'json',
          'q': '$logradouro, $localidade, $uf, Brasil',
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

  Future<void> _updateMapPosition() async {
    if (_latitude == null || _longitude == null) return;
    try {
      _mapController.move(LatLng(_latitude!, _longitude!), 15);
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.dio.patch(
        '/cells/${widget.cell['id']}',
        data: {
          'name': _nameCtrl.text.trim(),
          'address': _addressCtrl.text.trim(),
          if (_estadoId != null) 'estadoId': _estadoId,
          if (_cidadeId != null) 'cidadeId': _cidadeId,
          if (_bairroId != null) 'bairroId': _bairroId,
          'time': _timeCtrl.text.trim(),
          if (_latitude != null) 'latitude': _latitude else 'latitude': null,
          if (_longitude != null)
            'longitude': _longitude
          else
            'longitude': null,
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
              // ── CEP ──────────────────────────────────────────────────────
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
              AppTextField(
                controller: _addressCtrl,
                label: 'Rua / número',
                hint: 'Rua, número',
              ),
              const SizedBox(height: AppSpacing.base),
              AddressSelector(
                dio: widget.dio,
                initialEstadoId: _estadoId,
                initialCidadeId: _cidadeId,
                initialBairroId: _bairroId,
                onChanged: (id) {
                  setState(() => _bairroId = id);
                  _updateMapPosition();
                },
                isRequired: false,
              ),

              // ── Mapa ──────────────────────────────────────────────────────
              const SizedBox(height: AppSpacing.base),
              Text('Localização no Mapa', style: AppTypography.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _latitude != null
                    ? 'Toque no mapa para ajustar a posição da célula'
                    : 'Informe um CEP ou toque no mapa para definir a localização',
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
                      initialCenter: _latitude != null
                          ? LatLng(_latitude!, _longitude!)
                          : const LatLng(-14.235, -51.925),
                      initialZoom: _latitude != null ? 15.0 : 4.0,
                      onTap: (_, point) => setState(() {
                        _latitude = point.latitude;
                        _longitude = point.longitude;
                      }),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.app',
                      ),
                      if (_latitude != null)
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
              if (_latitude != null) ...[
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
  const _AddressMapSheet({
    required this.title,
    required this.address,
    this.latitude,
    this.longitude,
  });

  final String title;
  final String address;
  final double? latitude;
  final double? longitude;

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
      // Se temos coordenadas, usar elas diretamente (mais preciso)
      if (widget.latitude != null && widget.longitude != null) {
        if (!mounted) return;
        setState(() {
          _position = LatLng(widget.latitude!, widget.longitude!);
          _loading = false;
        });
        return;
      }

      // Caso contrário, tentar geocoding do endereço
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
