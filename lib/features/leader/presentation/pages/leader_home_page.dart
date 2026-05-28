import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/auth_storage.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';

/// Leader Panel — main hub for cell leaders
/// Shows: forwarded visitors, attendance, materials, spiritual history
class LeaderHomePage extends StatefulWidget {
  const LeaderHomePage({super.key});

  @override
  State<LeaderHomePage> createState() => _LeaderHomePageState();
}

class _LeaderHomePageState extends State<LeaderHomePage> {
  int _selectedTab = 0;

  static const _tabs = [
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Painel do Líder'),
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
      ),
      body: IndexedStack(
        index: _selectedTab,
        children: [
          const _LeaderVisitorsTab(),
          const _CellMembersTab(),
          const _AttendanceTab(),
          const _MaterialsTab(),
          const _SpiritualHistoryTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (i) => setState(() => _selectedTab = i),
        destinations: _tabs,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1: VISITORS
// ═══════════════════════════════════════════════════════════════════════════

class _LeaderVisitorsTab extends StatefulWidget {
  const _LeaderVisitorsTab();

  @override
  State<_LeaderVisitorsTab> createState() => _LeaderVisitorsTabState();
}

class _LeaderVisitorsTabState extends State<_LeaderVisitorsTab> {
  late final Dio _dio;
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _loading = true;
  String? _error;
  // Primary cell id (first cell of leader) for assigning visitors
  String? _cellId;
  // All cell ids this leader manages
  List<String> _myCellIds = [];
  List<_VisitorData> _allVisitors = [];

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
      final results = await Future.wait([
        _dio.get('/cells/my-cell'),
        _dio.get('/visitors'),
      ]);
      final cellResp = results[0];
      final visitorsResp = results[1];
      // Backend now returns { cells: [...] }
      final cellsRaw = (cellResp.data as Map<String, dynamic>)['cells'];
      final List<dynamic> cellList = cellsRaw is List ? cellsRaw : <dynamic>[];
      final myCellIds = cellList
          .map((c) => (c as Map<String, dynamic>)['id'] as String)
          .toList();
      final data = (visitorsResp.data as Map<String, dynamic>)['data'] as List;
      if (!mounted) return;
      setState(() {
        _myCellIds = myCellIds;
        _cellId = myCellIds.isNotEmpty ? myCellIds.first : null;
        _allVisitors = data
            .map((e) => _VisitorData.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar visitantes';
        _loading = false;
      });
    }
  }

  List<_VisitorData> get _myCellVisitors {
    if (_myCellIds.isEmpty) return [];
    final q = _query.toLowerCase();
    return _allVisitors.where((v) {
      if (!_myCellIds.contains(v.cellId)) return false;
      if (q.isEmpty) return true;
      return v.name.toLowerCase().contains(q) || v.phone.contains(q);
    }).toList();
  }

  List<_VisitorData> get _otherVisitors {
    final q = _query.toLowerCase();
    return _allVisitors.where((v) {
      if (_myCellIds.contains(v.cellId)) return false;
      if (q.isEmpty) return true;
      return v.name.toLowerCase().contains(q) || v.phone.contains(q);
    }).toList();
  }

  Future<void> _assignToCell(_VisitorData visitor) async {
    final cid = _cellId;
    if (cid == null) return;
    try {
      await _dio.patch(
        '/visitors/${visitor.id}/assign-cell',
        data: {'cellId': cid},
      );
      _loadData();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?['message'] as String? ??
                'Erro ao vincular visitante',
          ),
          backgroundColor: AppColors.error,
        ),
      );
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

    final myCellList = _myCellVisitors;
    final otherList = _otherVisitors;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  AppSearchField(
                    hint: 'Pesquisar visitante...',
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  AppSectionHeader(title: 'Visitantes da Minha Célula'),
                  const SizedBox(height: AppSpacing.sm),
                ]),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePaddingH,
              ),
              sliver: myCellList.isEmpty
                  ? SliverToBoxAdapter(
                      child: AppEmptyState(
                        title: 'Nenhum visitante na célula',
                        subtitle:
                            'Cadastre um novo visitante ou vincule um visitante já cadastrado.',
                        icon: Icons.people_outline,
                        actionLabel: 'Novo visitante',
                        action: () => _showNewVisitorSheet(context),
                      ),
                    )
                  : SliverList.separated(
                      itemCount: myCellList.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) => _VisitorListTile(
                        visitor: myCellList[i],
                        onOpenDetails: () => _openVisitorDetails(myCellList[i]),
                      ),
                    ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pagePaddingH,
                AppSpacing.xl,
                AppSpacing.pagePaddingH,
                AppSpacing.sm,
              ),
              sliver: SliverToBoxAdapter(
                child: AppSectionHeader(title: 'Outros Visitantes'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePaddingH,
              ),
              sliver: otherList.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          top: AppSpacing.base,
                          bottom: AppSpacing.xl,
                        ),
                        child: Text(
                          'Nenhum outro visitante encontrado',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    )
                  : SliverList.separated(
                      itemCount: otherList.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, i) => _VisitorListTile(
                        visitor: otherList[i],
                        showAssignButton: true,
                        onOpenDetails: () => _openVisitorDetails(otherList[i]),
                        onAssign: () => _assignToCell(otherList[i]),
                      ),
                    ),
            ),
            const SliverPadding(
              padding: EdgeInsets.only(bottom: AppSpacing.xl2),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewVisitorSheet(context),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Novo visitante'),
      ),
    );
  }

  Future<void> _showNewVisitorSheet(BuildContext context) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NewVisitorSheet(dio: _dio, cellId: _cellId),
    );
    if (created == true) _loadData();
  }

  Future<void> _openVisitorDetails(_VisitorData visitor) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _VisitorDetailSheet(visitor: visitor, dio: _dio, cellId: _cellId),
    );

    if (changed == true) {
      _loadData();
    }
  }
}

class _VisitorData {
  final String id;
  final String name;
  final String status;
  final String? cellId;
  final String? memberId;
  final String time;
  final String phone;
  final String neighborhood;
  final String address;

  const _VisitorData(
    this.id,
    this.name,
    this.status,
    this.cellId,
    this.memberId,
    this.time,
    this.phone,
    this.neighborhood,
    this.address,
  );

  factory _VisitorData.fromJson(Map<String, dynamic> json) {
    final createdAt = DateTime.tryParse((json['createdAt'] as String?) ?? '');
    return _VisitorData(
      json['id'] as String,
      (json['name'] as String?) ?? 'Sem nome',
      (json['status'] as String?) ?? 'novo',
      json['cellId'] as String?,
      json['memberId'] as String?,
      _relativeTime(createdAt),
      (json['phone'] as String?) ?? 'Nao informado',
      (json['neighborhood'] as String?) ?? 'Nao informado',
      (json['address'] as String?) ?? 'Nao informado',
    );
  }

  static String _relativeTime(DateTime? createdAt) {
    if (createdAt == null) return 'Sem data';
    final diff = DateTime.now().difference(createdAt);
    if (diff.inDays == 0) return 'hoje';
    if (diff.inDays == 1) return 'ha 1 dia';
    if (diff.inDays < 7) return 'ha ${diff.inDays} dias';
    if (diff.inDays < 14) return 'ha 1 sem.';
    return 'ha ${(diff.inDays / 7).round()} sem.';
  }
}

class _VisitorListTile extends StatelessWidget {
  const _VisitorListTile({
    required this.visitor,
    required this.onOpenDetails,
    this.showAssignButton = false,
    this.onAssign,
  });

  final _VisitorData visitor;
  final VoidCallback onOpenDetails;
  final bool showAssignButton;
  final VoidCallback? onAssign;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          AppAvatar(
            initials: visitor.name.split(' ').map((e) => e[0]).take(2).join(),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(visitor.name, style: AppTypography.titleSmall),
                const SizedBox(height: AppSpacing.xs2),
                VisitorStatusBadge(status: visitor.status),
              ],
            ),
          ),
          if (showAssignButton && onAssign != null)
            AppButton(
              label: 'Vincular',
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
              isFullWidth: false,
              prefixIcon: Icons.link_outlined,
              onPressed: onAssign,
            )
          else
            AppButton(
              label: 'Ver detalhes',
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
              isFullWidth: false,
              suffixIcon: Icons.chevron_right,
              onPressed: onOpenDetails,
            ),
        ],
      ),
    );
  }
}

// ── New Visitor Sheet ──────────────────────────────────────────────────────

class _NewVisitorSheet extends StatefulWidget {
  const _NewVisitorSheet({required this.dio, this.cellId});

  final Dio dio;
  final String? cellId;

  @override
  State<_NewVisitorSheet> createState() => _NewVisitorSheetState();
}

class _NewVisitorSheetState extends State<_NewVisitorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.dio.post(
        '/visitors',
        data: {
          'name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          if (_neighborhoodCtrl.text.trim().isNotEmpty)
            'neighborhood': _neighborhoodCtrl.text.trim(),
          if (_addressCtrl.text.trim().isNotEmpty)
            'address': _addressCtrl.text.trim(),
          if (widget.cellId != null) 'cellId': widget.cellId,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?['message'] as String? ??
                'Erro ao cadastrar visitante',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
          child: Form(
            key: _formKey,
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
                Text('Novo Visitante', style: AppTypography.headlineSmall),
                if (widget.cellId != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'O visitante será vinculado automaticamente à sua célula.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome completo *',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (v) => (v == null || v.trim().length < 2)
                      ? 'Informe o nome'
                      : null,
                ),
                const SizedBox(height: AppSpacing.base),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone *',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().length < 8)
                      ? 'Informe o telefone'
                      : null,
                ),
                const SizedBox(height: AppSpacing.base),
                TextFormField(
                  controller: _neighborhoodCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Bairro',
                    prefixIcon: Icon(Icons.location_city_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                TextFormField(
                  controller: _addressCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Endereço',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: _saving ? 'Salvando...' : 'Cadastrar visitante',
                  prefixIcon: Icons.check,
                  onPressed: _saving ? null : _save,
                ),
                const SizedBox(height: AppSpacing.xl2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Visitor Detail Sheet ───────────────────────────────────────────────────

class _VisitorDetailSheet extends StatefulWidget {
  const _VisitorDetailSheet({
    required this.visitor,
    required this.dio,
    this.cellId,
  });

  final _VisitorData visitor;
  final Dio dio;
  final String? cellId;

  @override
  State<_VisitorDetailSheet> createState() => _VisitorDetailSheetState();
}

class _VisitorDetailSheetState extends State<_VisitorDetailSheet> {
  late String _status;
  bool _updatingStatus = false;
  bool _converting = false;
  bool _assigningCell = false;

  @override
  void initState() {
    super.initState();
    _status = widget.visitor.status;
  }

  Future<void> _assignCell(String? cellId) async {
    setState(() => _assigningCell = true);
    try {
      await widget.dio.patch(
        '/visitors/${widget.visitor.id}/assign-cell',
        data: {'cellId': cellId},
      );
      if (!mounted) return;
      setState(() => _assigningCell = false);
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _assigningCell = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?['message'] as String? ??
                'Erro ao atualizar célula',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _updateStatus(String status) async {
    if (_updatingStatus || status == _status) return;

    setState(() => _updatingStatus = true);
    try {
      await widget.dio.patch(
        '/visitors/${widget.visitor.id}/status',
        data: {
          'status': status,
          if (widget.visitor.cellId != null) 'cellId': widget.visitor.cellId,
        },
      );
      if (!mounted) return;
      setState(() {
        _status = status;
        _updatingStatus = false;
      });
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _updatingStatus = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?['message'] as String? ??
                'Erro ao atualizar status',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _convertToMember() async {
    if (_converting || widget.visitor.memberId != null) return;
    setState(() => _converting = true);
    try {
      await widget.dio.patch(
        '/visitors/${widget.visitor.id}/convert-member',
        data: {
          if (widget.visitor.cellId != null) 'cellId': widget.visitor.cellId,
        },
      );
      if (!mounted) return;
      setState(() => _converting = false);
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _converting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?['message'] as String? ??
                'Erro ao converter visitante em membro',
          ),
          backgroundColor: AppColors.error,
        ),
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
                    initials: widget.visitor.name
                        .split(' ')
                        .map((e) => e[0])
                        .take(2)
                        .join(),
                    size: 56,
                  ),
                  const SizedBox(width: AppSpacing.base),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.visitor.name,
                          style: AppTypography.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        VisitorStatusBadge(status: _status),
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
                      value: widget.visitor.phone,
                    ),
                    const Divider(height: 1),
                    _TappableDetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Endereço',
                      value: widget.visitor.address,
                      onTap: () {
                        Navigator.of(context).pop();
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(20),
                            ),
                          ),
                          builder: (_) => _VisitorMapSheet(
                            address: widget.visitor.address,
                            visitorName: widget.visitor.name,
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _DetailRow(
                      icon: Icons.access_time_outlined,
                      label: 'Cadastrado',
                      value: widget.visitor.time,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.base),

              if (widget.cellId != null) ...[
                if (widget.visitor.cellId == widget.cellId)
                  AppButton(
                    label: _assigningCell
                        ? 'Removendo...'
                        : 'Remover da minha célula',
                    variant: AppButtonVariant.outline,
                    prefixIcon: Icons.link_off_outlined,
                    onPressed: _assigningCell ? null : () => _assignCell(null),
                  )
                else
                  AppButton(
                    label: _assigningCell
                        ? 'Vinculando...'
                        : 'Vincular à minha célula',
                    variant: AppButtonVariant.secondary,
                    prefixIcon: Icons.link_outlined,
                    onPressed: _assigningCell
                        ? null
                        : () => _assignCell(widget.cellId),
                  ),
                const SizedBox(height: AppSpacing.sm),
              ],

              AppButton(
                label: widget.visitor.memberId != null
                    ? 'Já é membro da célula'
                    : _converting
                    ? 'Convertendo...'
                    : 'Transformar em membro da célula',
                variant: AppButtonVariant.secondary,
                prefixIcon: Icons.person_add_alt_1_outlined,
                onPressed: widget.visitor.memberId != null || _converting
                    ? null
                    : _convertToMember,
              ),

              const SizedBox(height: AppSpacing.xl),

              Text('Alterar status', style: AppTypography.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  _StatusChip(
                    label: 'Novo',
                    status: 'novo',
                    selectedStatus: _status,
                    onTap: _updateStatus,
                  ),
                  _StatusChip(
                    label: 'Em acompanhamento',
                    status: 'em_acompanhamento',
                    selectedStatus: _status,
                    onTap: _updateStatus,
                  ),
                  _StatusChip(
                    label: 'Integrado',
                    status: 'integrado',
                    selectedStatus: _status,
                    onTap: _updateStatus,
                  ),
                  _StatusChip(
                    label: 'Inativo',
                    status: 'inativo',
                    selectedStatus: _status,
                    onTap: _updateStatus,
                  ),
                ],
              ),

              if (_updatingStatus)
                const Padding(
                  padding: EdgeInsets.only(top: AppSpacing.sm),
                  child: LinearProgressIndicator(),
                ),

              const SizedBox(height: AppSpacing.xl2),
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

class _TappableDetailRow extends StatelessWidget {
  const _TappableDetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

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
      trailing: const Icon(
        Icons.map_outlined,
        color: AppColors.primary,
        size: 20,
      ),
      onTap: onTap,
    );
  }
}

// ── Visitor Map Sheet ──────────────────────────────────────────────────────

class _VisitorMapSheet extends StatefulWidget {
  const _VisitorMapSheet({required this.address, required this.visitorName});

  final String address;
  final String visitorName;

  @override
  State<_VisitorMapSheet> createState() => _VisitorMapSheetState();
}

class _VisitorMapSheetState extends State<_VisitorMapSheet> {
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
        // Fallback: São Paulo center
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
                Row(
                  children: [
                    const Icon(Icons.location_on, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.visitorName,
                            style: AppTypography.titleSmall,
                          ),
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
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xl),
                      child: Text(
                        _error!,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.status,
    required this.selectedStatus,
    required this.onTap,
  });

  final String label;
  final String status;
  final String selectedStatus;
  final void Function(String status) onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = status == selectedStatus;
    final color = _colorForStatus(status);

    return ChoiceChip(
      label: Text(
        label,
        style: AppTypography.labelMedium.copyWith(
          color: isSelected ? AppColors.white : color,
          fontWeight: FontWeight.w600,
        ),
      ),
      selected: isSelected,
      selectedColor: color,
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide(color: color.withValues(alpha: 0.35)),
      onSelected: (_) => onTap(status),
    );
  }

  Color _colorForStatus(String value) {
    return switch (value) {
      'novo' => AppColors.statusNew,
      'em_acompanhamento' => AppColors.statusFollowing,
      'integrado' => AppColors.statusIntegrated,
      'inativo' => AppColors.statusInactive,
      _ => AppColors.grey500,
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 2: CELL MEMBERS
// ═══════════════════════════════════════════════════════════════════════════

class _CellMembersTab extends StatefulWidget {
  const _CellMembersTab();

  @override
  State<_CellMembersTab> createState() => _CellMembersTabState();
}

class _CellMember {
  final String id;
  final String name;
  final String phone;
  final String cellId;
  final String cellName;

  const _CellMember({
    required this.id,
    required this.name,
    required this.phone,
    required this.cellId,
    required this.cellName,
  });

  factory _CellMember.fromJson(
    Map<String, dynamic> json,
    String cellId,
    String cellName,
  ) => _CellMember(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    cellId: cellId,
    cellName: cellName,
  );
}

class _CellInfo {
  final String id;
  final String name;

  const _CellInfo({required this.id, required this.name});
}

class _CellMembersTabState extends State<_CellMembersTab> {
  late final Dio _dio;
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  String _query = '';
  List<_CellInfo> _cells = [];
  List<_CellMember> _members = [];

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
      final cellResp = await _dio.get('/cells/my-cell');
      final cellsRaw =
          (cellResp.data as Map<String, dynamic>)['cells'] as List? ?? [];
      final cells = cellsRaw
          .map(
            (c) => _CellInfo(
              id: (c as Map<String, dynamic>)['id'] as String,
              name: c['name'] as String? ?? '',
            ),
          )
          .toList();

      final allMembers = <_CellMember>[];
      for (final cell in cells) {
        final membResp = await _dio.get('/cells/${cell.id}/members');
        final membList =
            (membResp.data as Map<String, dynamic>)['members'] as List? ?? [];
        allMembers.addAll(
          membList.map(
            (m) => _CellMember.fromJson(
              m as Map<String, dynamic>,
              cell.id,
              cell.name,
            ),
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _cells = cells;
        _members = allMembers;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar membros';
        _loading = false;
      });
    }
  }

  List<_CellMember> get _filtered {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _members;
    return _members
        .where((m) => m.name.toLowerCase().contains(q) || m.phone.contains(q))
        .toList();
  }

  Future<void> _addMember(String cellId) async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddMemberSheet(dio: _dio, cellId: cellId),
    );
    if (added == true) _loadData();
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
          children: [
            AppSearchField(
              hint: 'Pesquisar membro...',
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: AppSpacing.base),
            AppSectionHeader(title: 'Membros (${filtered.length})'),
            const SizedBox(height: AppSpacing.sm),
            if (filtered.isEmpty)
              AppEmptyState(
                title: 'Nenhum membro cadastrado',
                subtitle:
                    'Adicione membros à sua célula usando o botão abaixo.',
                icon: Icons.group_outlined,
              )
            else
              ...filtered.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AppCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        AppAvatar(
                          initials: m.name
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
                              Text(m.name, style: AppTypography.titleSmall),
                              const SizedBox(height: AppSpacing.xs2),
                              Text(
                                m.phone,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (_cells.length > 1)
                                Text(
                                  m.cellName,
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.primary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: _cells.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _cells.length == 1
                  ? _addMember(_cells.first.id)
                  : _showCellPicker(context),
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Adicionar membro'),
            ),
    );
  }

  Future<void> _showCellPicker(BuildContext context) async {
    final picked = await showDialog<String>(
      context: context,
      builder: (_) => SimpleDialog(
        title: const Text('Selecionar célula'),
        children: _cells
            .map(
              (c) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, c.id),
                child: Text(c.name),
              ),
            )
            .toList(),
      ),
    );
    if (picked != null) _addMember(picked);
  }
}

// ── Add member sheet ────────────────────────────────────────────────────────

class _AddMemberSheet extends StatefulWidget {
  const _AddMemberSheet({required this.dio, required this.cellId});

  final Dio dio;
  final String cellId;

  @override
  State<_AddMemberSheet> createState() => _AddMemberSheetState();
}

class _AddMemberSheetState extends State<_AddMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.dio.post(
        '/cells/${widget.cellId}/members',
        data: {
          'name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          if (_emailCtrl.text.trim().isNotEmpty)
            'email': _emailCtrl.text.trim(),
          if (_addressCtrl.text.trim().isNotEmpty)
            'address': _addressCtrl.text.trim(),
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?['message'] as String? ??
                'Erro ao adicionar membro',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePaddingH,
        AppSpacing.md,
        AppSpacing.pagePaddingH,
        MediaQuery.of(context).viewInsets.bottom + AppSpacing.xl,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
            Text('Adicionar Membro', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.base),
            AppTextField(
              label: 'Nome completo',
              controller: _nameCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Telefone',
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.trim().length < 8)
                  ? 'Informe o telefone'
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'E-mail (opcional)',
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Endereço (opcional)',
              controller: _addressCtrl,
            ),
            const SizedBox(height: AppSpacing.base),
            AppButton(
              label: 'Salvar',
              onPressed: _saving ? null : _save,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3: ATTENDANCE
// ═══════════════════════════════════════════════════════════════════════════

class _AttendanceTab extends StatefulWidget {
  const _AttendanceTab();

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  late final Dio _dio;
  bool _loading = true;
  String? _error;
  String? _cellId;
  List<Map<String, dynamic>> _meetings = [];

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
      final cellResp = await _dio.get('/cells/my-cell');
      final cellsRaw =
          (cellResp.data as Map<String, dynamic>)['cells'] as List? ?? [];
      if (cellsRaw.isEmpty)
        throw Exception('Nenhuma célula vinculada ao líder');
      final cellId = (cellsRaw.first as Map<String, dynamic>)['id'] as String;
      final meetingsResp = await _dio.get('/attendance/cell/$cellId/meetings');
      final meetings =
          ((meetingsResp.data as Map<String, dynamic>)['meetings'] as List)
              .cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _cellId = cellId;
        _meetings = meetings;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[Presença] Erro: $e\n$st');
      if (!mounted) return;
      final String detail;
      if (e is DioException) {
        final apiMsg = e.response?.data?['error']?['message'] as String?;
        final status = e.response?.statusCode;
        detail = apiMsg != null
            ? 'HTTP $status: $apiMsg'
            : 'HTTP $status — ${e.message ?? e.type.name}';
      } else {
        detail = e.toString();
      }
      setState(() {
        _error = 'Erro ao carregar presenças:\n$detail';
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
              textAlign: TextAlign.center,
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

    return RefreshIndicator(
      onRefresh: _loadData,
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                AppSectionHeader(
                  title: 'Registro de Presença',
                  actionLabel: 'Novo encontro',
                  onAction: () => _showNewMeetingSheet(context),
                ),
                const SizedBox(height: AppSpacing.base),
                if (_meetings.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xl),
                    child: Center(
                      child: Text(
                        'Nenhum encontro registrado ainda.',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  ..._meetings.map(
                    (m) => Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: _MeetingSummaryCard(
                        meeting: m,
                        onTap: () => _openMeetingDetails(m),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpacing.xl),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _showNewMeetingSheet(BuildContext context) {
    final cid = _cellId;
    if (cid == null) return;
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NewMeetingSheet(dio: _dio, cellId: cid),
    ).then((created) {
      if (created == true) _loadData();
    });
  }

  Future<void> _openMeetingDetails(Map<String, dynamic> meeting) async {
    final cid = _cellId;
    if (cid == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MeetingAttendanceSheet(
        dio: _dio,
        cellId: cid,
        meetingDateIso: meeting['meetingDate'] as String,
      ),
    );

    if (changed == true) {
      _loadData();
    }
  }
}

/// Card that shows real meeting summary data from the API.
class _MeetingSummaryCard extends StatelessWidget {
  const _MeetingSummaryCard({required this.meeting, this.onTap});

  final Map<String, dynamic> meeting;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final d = DateTime.parse(meeting['meetingDate'] as String).toLocal();
    final label =
        'Encontro de ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final total = (meeting['total'] as num).toInt();
    final present = (meeting['present'] as num).toInt();
    final pct = total > 0 ? (present / total * 100).round() : 0;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_available_outlined,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: Text(label, style: AppTypography.titleSmall)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const SizedBox(width: 36),
              Text(
                '$present de $total presentes ($pct%)',
                style: AppTypography.bodySmall.copyWith(
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

class _NewMeetingSheet extends StatefulWidget {
  const _NewMeetingSheet({required this.dio, required this.cellId});

  final Dio dio;
  final String cellId;

  @override
  State<_NewMeetingSheet> createState() => _NewMeetingSheetState();
}

class _NewMeetingSheetState extends State<_NewMeetingSheet> {
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  Future<void> _create() async {
    setState(() => _saving = true);
    try {
      await widget.dio.post(
        '/attendance/cell/${widget.cellId}/meetings',
        data: {'meetingDate': _selectedDate.toIso8601String()},
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?['message'] as String? ??
                'Erro ao criar encontro',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
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
            Text('Novo Encontro', style: AppTypography.headlineSmall),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Data do encontro',
              style: AppTypography.labelMedium.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.grey700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            AppCard(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                    style: AppTypography.titleSmall,
                  ),
                  const Spacer(),
                  const Icon(Icons.edit_outlined, color: AppColors.grey400),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Criar encontro',
              prefixIcon: Icons.add,
              isLoading: _saving,
              onPressed: _saving ? null : _create,
            ),
            const SizedBox(height: AppSpacing.base),
          ],
        ),
      ),
    );
  }
}

class _MeetingAttendanceSheet extends StatefulWidget {
  const _MeetingAttendanceSheet({
    required this.dio,
    required this.cellId,
    required this.meetingDateIso,
  });

  final Dio dio;
  final String cellId;
  final String meetingDateIso;

  @override
  State<_MeetingAttendanceSheet> createState() =>
      _MeetingAttendanceSheetState();
}

class _MeetingAttendanceSheetState extends State<_MeetingAttendanceSheet> {
  bool _loading = true;
  bool _saving = false;
  String? _error;

  /// Unified list of participants (visitors + cell members).
  /// Each map has: id, name, _type ('visitor' | 'member')
  List<Map<String, dynamic>> _participants = [];
  Set<String> _presentIds = <String>{};
  Set<String> _initialPresentIds = <String>{};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        widget.dio.get(
          '/visitors',
          queryParameters: {'cellId': widget.cellId, 'pageSize': 100},
        ),
        widget.dio.get('/cells/${widget.cellId}/members'),
        widget.dio.get(
          '/attendance/cell/${widget.cellId}',
          queryParameters: {'date': widget.meetingDateIso},
        ),
      ]);

      final visitorsResp = results[0];
      final membersResp = results[1];
      final attendanceResp = results[2];

      final visitorsData = visitorsResp.data as Map<String, dynamic>;
      final rawVisitors =
          (visitorsData['data'] ?? visitorsData['visitors'] ?? []) as List;

      final membersData = membersResp.data as Map<String, dynamic>;
      final rawMembers = (membersData['members'] ?? []) as List;

      final attendances =
          ((attendanceResp.data as Map<String, dynamic>)['attendances'] as List)
              .cast<Map<String, dynamic>>();

      // Build unified participant list: visitors first, then members not yet
      // represented as visitors (i.e. without a sourceVisitorId that is
      // already in the visitors list).
      final visitorIds = rawVisitors
          .cast<Map<String, dynamic>>()
          .map((v) => v['id'] as String)
          .toSet();

      final participants = <Map<String, dynamic>>[];

      for (final v in rawVisitors.cast<Map<String, dynamic>>()) {
        participants.add({...v, '_type': 'visitor'});
      }

      for (final m in rawMembers.cast<Map<String, dynamic>>()) {
        final sourceId = m['sourceVisitorId'] as String?;
        // Skip members whose source visitor is already in the list
        if (sourceId != null && visitorIds.contains(sourceId)) continue;
        participants.add({...m, '_type': 'member'});
      }

      // Collect which IDs are present (visitors by visitorId, members by memberId)
      final presentIds = <String>{};
      for (final a in attendances) {
        if ((a['isPresent'] as bool?) ?? false) {
          final vid = a['visitorId'] as String?;
          final mid = a['memberId'] as String?;
          if (vid != null) presentIds.add(vid);
          if (mid != null) presentIds.add(mid);
        }
      }

      if (!mounted) return;
      setState(() {
        _participants = participants;
        _presentIds = presentIds;
        _initialPresentIds = Set<String>.from(presentIds);
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar participantes';
        _loading = false;
      });
    }
  }

  Future<void> _reloadVisitorsOnly() async {
    try {
      final results = await Future.wait([
        widget.dio.get(
          '/visitors',
          queryParameters: {'cellId': widget.cellId, 'pageSize': 100},
        ),
        widget.dio.get('/cells/${widget.cellId}/members'),
      ]);

      final visitorsData = results[0].data as Map<String, dynamic>;
      final rawVisitors =
          (visitorsData['data'] ?? visitorsData['visitors'] ?? []) as List;

      final membersData = results[1].data as Map<String, dynamic>;
      final rawMembers = (membersData['members'] ?? []) as List;

      final visitorIds = rawVisitors
          .cast<Map<String, dynamic>>()
          .map((v) => v['id'] as String)
          .toSet();

      final participants = <Map<String, dynamic>>[];
      for (final v in rawVisitors.cast<Map<String, dynamic>>()) {
        participants.add({...v, '_type': 'visitor'});
      }
      for (final m in rawMembers.cast<Map<String, dynamic>>()) {
        final sourceId = m['sourceVisitorId'] as String?;
        if (sourceId != null && visitorIds.contains(sourceId)) continue;
        participants.add({...m, '_type': 'member'});
      }

      final allIds = participants.map((p) => p['id'] as String).toSet();

      if (!mounted) return;
      setState(() {
        _participants = participants;
        _presentIds = _presentIds.where(allIds.contains).toSet();
        _initialPresentIds = _initialPresentIds.where(allIds.contains).toSet();
      });
    } catch (_) {
      // Keep current list if refresh fails after creating visitor.
    }
  }

  Future<void> _save() async {
    if (_saving) return;

    final changedParticipants = _participants.where((p) {
      final id = p['id'] as String;
      return _presentIds.contains(id) != _initialPresentIds.contains(id);
    }).toList();

    if (changedParticipants.isEmpty) {
      if (!mounted) return;
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _saving = true);
    try {
      await Future.wait(
        changedParticipants.map((p) {
          final id = p['id'] as String;
          final isMember = (p['_type'] as String?) == 'member';
          return widget.dio.post(
            '/attendance',
            data: {
              if (isMember) 'memberId': id else 'visitorId': id,
              'cellId': widget.cellId,
              'meetingDate': widget.meetingDateIso,
              'isPresent': _presentIds.contains(id),
            },
          );
        }),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?['message'] as String? ??
                'Erro ao salvar presenças',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showAddVisitorSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NewVisitorSheet(dio: widget.dio, cellId: widget.cellId),
    );

    if (created == true) {
      _reloadVisitorsOnly();
    }
  }

  String _formatMeetingDate() {
    final d = DateTime.parse(widget.meetingDateIso).toLocal();
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, controller) => SingleChildScrollView(
            controller: controller,
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
                Text('Participantes', style: AppTypography.headlineSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Encontro de ${_formatMeetingDate()}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                AppButton(
                  label: 'Incluir visitante',
                  variant: AppButtonVariant.outline,
                  isFullWidth: false,
                  prefixIcon: Icons.person_add_outlined,
                  onPressed: _showAddVisitorSheet,
                ),
                const SizedBox(height: AppSpacing.base),
                if (_loading)
                  const Center(child: CircularProgressIndicator())
                else if (_error != null)
                  Center(
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
                          onPressed: _loadInitialData,
                        ),
                      ],
                    ),
                  )
                else if (_participants.isEmpty)
                  AppEmptyState(
                    title: 'Nenhum participante na célula',
                    subtitle: 'Use o botão acima para incluir visitante.',
                    icon: Icons.people_outline,
                  )
                else
                  Column(
                    children: _participants.map((participant) {
                      final participantId = participant['id'] as String;
                      final name =
                          (participant['name'] as String?) ?? 'Sem nome';
                      final isMember =
                          (participant['_type'] as String?) == 'member';
                      final checked = _presentIds.contains(participantId);

                      return AppCard(
                        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                        onTap: () {
                          setState(() {
                            if (checked) {
                              _presentIds.remove(participantId);
                            } else {
                              _presentIds.add(participantId);
                            }
                          });
                        },
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(name, style: AppTypography.titleSmall),
                                  if (isMember)
                                    Text(
                                      'Membro',
                                      style: AppTypography.labelSmall.copyWith(
                                        color: AppColors.primary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Checkbox(
                              value: checked,
                              onChanged: (v) {
                                setState(() {
                                  if (v ?? false) {
                                    _presentIds.add(participantId);
                                  } else {
                                    _presentIds.remove(participantId);
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: AppSpacing.xl),
                AppButton(
                  label: 'Salvar presença',
                  prefixIcon: Icons.check_circle_outline,
                  isLoading: _saving,
                  onPressed: (_loading || _saving || _error != null)
                      ? null
                      : _save,
                ),
                const SizedBox(height: AppSpacing.base),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3: MATERIALS
// ═══════════════════════════════════════════════════════════════════════════

class _MaterialsTab extends StatefulWidget {
  const _MaterialsTab();

  @override
  State<_MaterialsTab> createState() => _MaterialsTabState();
}

class _MaterialData {
  final String id;
  final String title;
  final String type;
  final int sizeBytes;

  const _MaterialData({
    required this.id,
    required this.title,
    required this.type,
    required this.sizeBytes,
  });

  factory _MaterialData.fromJson(Map<String, dynamic> json) => _MaterialData(
    id: json['id'] as String,
    title: json['title'] as String,
    type: json['fileType'] as String,
    sizeBytes: json['sizeBytes'] as int,
  );

  String get size {
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
  }
}

class _MaterialsTabState extends State<_MaterialsTab> {
  late final Dio _dio;
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _loading = true;
  String? _error;
  List<_MaterialData> _materials = [];
  final Map<String, bool> _opening = {};

  @override
  void initState() {
    super.initState();
    _dio = DioClient(AuthStorage()).dio;
    _loadMaterials();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMaterials() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Get leader's cells first
      final cellResp = await _dio.get('/cells/my-cell');
      final cellsRaw =
          (cellResp.data as Map<String, dynamic>)['cells'] as List? ?? [];
      final cellIds = cellsRaw
          .map((c) => (c as Map<String, dynamic>)['id'] as String)
          .toList();

      // Load materials for each cell
      final allMaterials = <_MaterialData>[];
      for (final cellId in cellIds) {
        final resp = await _dio.get(
          '/materials',
          queryParameters: {'cellId': cellId},
        );
        final data =
            (resp.data as Map<String, dynamic>)['materials'] as List? ?? [];
        allMaterials.addAll(
          data.map((e) => _MaterialData.fromJson(e as Map<String, dynamic>)),
        );
      }

      if (!mounted) return;
      setState(() {
        _materials = allMaterials;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar materiais';
        _loading = false;
      });
    }
  }

  List<_MaterialData> get _filtered {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _materials;
    return _materials.where((m) => m.title.toLowerCase().contains(q)).toList();
  }

  Future<void> _downloadAndOpen(_MaterialData material) async {
    setState(() => _opening[material.id] = true);
    try {
      final resp = await _dio.get('/materials/${material.id}/download-url');
      final url = resp.data['url'] as String;
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Nao foi possivel abrir o arquivo');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _opening.remove(material.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao abrir o arquivo'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (!mounted) return;
    setState(() => _opening.remove(material.id));
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
              onPressed: _loadMaterials,
            ),
          ],
        ),
      );
    }

    final filtered = _filtered;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
      children: [
        AppSectionHeader(title: 'Materiais da Célula'),
        const SizedBox(height: AppSpacing.base),
        AppSearchField(
          hint: 'Pesquisar material...',
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: AppSpacing.base),
        if (filtered.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xl),
            child: Center(
              child: Text(
                'Nenhum material encontrado',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          )
        else
          ...filtered.map(
            (m) => _MaterialCard(
              material: m,
              isOpening: _opening[m.id] == true,
              onDownload: () => _downloadAndOpen(m),
              onView: () => _downloadAndOpen(m),
            ),
          ),
        const SizedBox(height: AppSpacing.xl),
      ],
    );
  }
}

class _MaterialCard extends StatelessWidget {
  const _MaterialCard({
    required this.material,
    required this.onDownload,
    required this.onView,
    required this.isOpening,
  });

  final _MaterialData material;
  final bool isOpening;
  final VoidCallback onDownload;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    final icon = switch (material.type) {
      'pdf' => Icons.picture_as_pdf_outlined,
      'ppt' => Icons.slideshow_outlined,
      'video' => Icons.play_circle_outline,
      'docx' => Icons.article_outlined,
      _ => Icons.attach_file_outlined,
    };
    final iconColor = switch (material.type) {
      'pdf' => AppColors.error,
      'ppt' => AppColors.warning,
      'video' => AppColors.primary,
      'docx' => AppColors.info,
      _ => AppColors.grey500,
    };

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: AppSpacing.iconLg),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(material.title, style: AppTypography.titleSmall),
                    Text(
                      material.size,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.visibility_outlined,
                  color: AppColors.grey500,
                ),
                tooltip: 'Visualizar',
                onPressed: isOpening ? null : onView,
              ),
              IconButton(
                icon: isOpening
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      )
                    : const Icon(
                        Icons.download_outlined,
                        color: AppColors.primary,
                      ),
                tooltip: 'Baixar',
                onPressed: isOpening ? null : onDownload,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 4: SPIRITUAL HISTORY
// ═══════════════════════════════════════════════════════════════════════════

class _SpiritualHistoryTab extends StatefulWidget {
  const _SpiritualHistoryTab();

  @override
  State<_SpiritualHistoryTab> createState() => _SpiritualHistoryTabState();
}

class _SpiritualHistoryTabState extends State<_SpiritualHistoryTab> {
  late final Dio _dio;
  bool _loading = true;
  String? _error;
  String? _cellId;
  List<Map<String, dynamic>> _events = [];

  static const _typeLabels = {
    'enviado_batismo': 'Enviado p/ Batismo',
    'batizado': 'Batizado',
    'enviado_treinamento_lider': 'Em Treinamento Líder',
    'concluiu_treinamento': 'Concluiu Treinamento',
    'tornou_se_lider': 'Tornou-se Líder',
  };

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
      final cellResp = await _dio.get('/cells/my-cell');
      final cellsRaw =
          (cellResp.data as Map<String, dynamic>)['cells'] as List? ?? [];
      if (cellsRaw.isEmpty)
        throw Exception('Nenhuma célula vinculada ao líder');
      final cellId = (cellsRaw.first as Map<String, dynamic>)['id'] as String;
      final histResp = await _dio.get('/spiritual-history/cell/$cellId');
      final history =
          ((histResp.data as Map<String, dynamic>)['history'] as List)
              .cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _cellId = cellId;
        _events = history;
        _loading = false;
      });
    } catch (e, st) {
      debugPrint('[Histórico] Erro: $e\n$st');
      if (!mounted) return;
      final String detail;
      if (e is DioException) {
        final apiMsg = e.response?.data?['error']?['message'] as String?;
        final status = e.response?.statusCode;
        detail = apiMsg != null
            ? 'HTTP $status: $apiMsg'
            : 'HTTP $status — ${e.message ?? e.type.name}';
      } else {
        detail = e.toString();
      }
      setState(() {
        _error = 'Erro ao carregar histórico:\n$detail';
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
              textAlign: TextAlign.center,
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

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        children: [
          AppSectionHeader(
            title: 'Histórico Espiritual',
            actionLabel: 'Adicionar',
            onAction: () => _showAddSheet(context),
          ),
          const SizedBox(height: AppSpacing.base),
          if (_events.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xl),
              child: Center(
                child: Text(
                  'Nenhum evento registrado',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          else
            ..._events.map(
              (e) => _HistoryEventCard(
                event: e,
                typeLabels: _typeLabels,
                onTap: () => _showDetail(context, e),
              ),
            ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final cid = _cellId;
    if (cid == null) return;
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddHistoryEventSheet(dio: _dio, cellId: cid),
    ).then((added) {
      if (added == true) _loadData();
    });
  }

  void _showDetail(BuildContext context, Map<String, dynamic> event) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) =>
          _HistoryDetailSheet(event: event, typeLabels: _typeLabels),
    );
  }
}

class _HistoryEventCard extends StatelessWidget {
  const _HistoryEventCard({
    required this.event,
    required this.typeLabels,
    required this.onTap,
  });

  final Map<String, dynamic> event;
  final Map<String, String> typeLabels;
  final VoidCallback onTap;

  static const _typeIcons = {
    'enviado_batismo': (Icons.water_outlined, AppColors.primary),
    'batizado': (Icons.water_drop_outlined, AppColors.info),
    'enviado_treinamento_lider': (Icons.school_outlined, AppColors.accent),
    'concluiu_treinamento': (
      Icons.workspace_premium_outlined,
      AppColors.success,
    ),
    'tornou_se_lider': (Icons.star_outline, AppColors.warning),
  };

  @override
  Widget build(BuildContext context) {
    final type = event['eventType'] as String? ?? '';
    final visitorName = event['visitorName'] as String? ?? 'Visitante';
    final label = typeLabels[type] ?? type.replaceAll('_', ' ');
    final iconData =
        _typeIcons[type] ?? (Icons.history_outlined, AppColors.grey500);
    final d = DateTime.parse(event['date'] as String).toLocal();

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: iconData.$2.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(iconData.$1, color: iconData.$2, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTypography.titleSmall),
                Text(
                  visitorName,
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
              Text(
                '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.grey400,
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.grey400),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryDetailSheet extends StatelessWidget {
  const _HistoryDetailSheet({required this.event, required this.typeLabels});

  final Map<String, dynamic> event;
  final Map<String, String> typeLabels;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          const SizedBox(height: AppSpacing.xl),
          Text('Detalhe do Evento', style: AppTypography.headlineSmall),
          const SizedBox(height: AppSpacing.xl),
          Builder(
            builder: (context) {
              final type = event['eventType'] as String? ?? '';
              final visitorName =
                  event['visitorName'] as String? ?? 'Visitante';
              final label = typeLabels[type] ?? type.replaceAll('_', ' ');
              final d = DateTime.parse(event['date'] as String).toLocal();
              final description = event['description'] as String? ?? '';
              return AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(
                        Icons.person_outline,
                        color: AppColors.primary,
                      ),
                      title: const Text('Visitante'),
                      subtitle: Text(visitorName),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.category_outlined,
                        color: AppColors.primary,
                      ),
                      title: const Text('Tipo de evento'),
                      subtitle: Text(label),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(
                        Icons.calendar_today_outlined,
                        color: AppColors.primary,
                      ),
                      title: const Text('Data'),
                      subtitle: Text(
                        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}',
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(
                          Icons.notes_outlined,
                          color: AppColors.primary,
                        ),
                        title: const Text('Descrição'),
                        subtitle: Text(description),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xl2),
        ],
      ),
    );
  }
}

class _AddHistoryEventSheet extends StatefulWidget {
  const _AddHistoryEventSheet({required this.dio, required this.cellId});

  final Dio dio;
  final String cellId;

  @override
  State<_AddHistoryEventSheet> createState() => _AddHistoryEventSheetState();
}

class _AddHistoryEventSheetState extends State<_AddHistoryEventSheet> {
  final _descCtrl = TextEditingController();
  String? _selectedVisitorId;
  String _selectedType = 'enviado_batismo';
  bool _loadingVisitors = true;
  bool _saving = false;
  List<Map<String, dynamic>> _visitors = [];

  static const _types = [
    ('enviado_batismo', 'Enviado para Batismo'),
    ('batizado', 'Batizado'),
    ('enviado_treinamento_lider', 'Enviado p/ Treinamento de Líder'),
    ('concluiu_treinamento', 'Concluiu Treinamento'),
    ('tornou_se_lider', 'Tornou-se Líder'),
  ];

  @override
  void initState() {
    super.initState();
    _loadVisitors();
  }

  Future<void> _loadVisitors() async {
    try {
      final resp = await widget.dio.get(
        '/visitors',
        queryParameters: {'cellId': widget.cellId},
      );
      final body = resp.data as Map<String, dynamic>;
      // API returns paginated response: { data: [...], total, page, ... }
      final rawList = (body['data'] ?? body['visitors'] ?? []) as List;
      final visitors = rawList.cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _visitors = visitors;
        _loadingVisitors = false;
        if (visitors.isNotEmpty) {
          _selectedVisitorId = visitors.first['id'] as String;
        }
      });
    } catch (e) {
      debugPrint('[AddHistorySheet] Erro ao carregar visitantes: $e');
      if (!mounted) return;
      setState(() => _loadingVisitors = false);
    }
  }

  Future<void> _save() async {
    final visitorId = _selectedVisitorId;
    if (visitorId == null) return;
    setState(() => _saving = true);
    try {
      await widget.dio.post(
        '/spiritual-history',
        data: {
          'visitorId': visitorId,
          'eventType': _selectedType,
          'description': _descCtrl.text,
          'date': DateTime.now().toIso8601String().substring(0, 10),
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?['message'] as String? ??
                'Erro ao registrar evento',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
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
              Text('Adicionar Evento', style: AppTypography.headlineSmall),
              const SizedBox(height: AppSpacing.xl),

              // Visitor
              Text(
                'Visitante',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (_loadingVisitors)
                const LinearProgressIndicator()
              else if (_visitors.isEmpty)
                Text(
                  'Nenhum visitante na célula',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: _selectedVisitorId,
                  items: _visitors
                      .map(
                        (v) => DropdownMenuItem(
                          value: v['id'] as String,
                          child: Text(v['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedVisitorId = v),
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

              const SizedBox(height: AppSpacing.base),

              // Event type
              Text(
                'Tipo de evento',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: _types
                    .map(
                      (t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _selectedType = v!),
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

              const SizedBox(height: AppSpacing.base),

              AppTextField(
                controller: _descCtrl,
                label: 'Descrição (opcional)',
                hint: 'Observações sobre o evento...',
                prefixIcon: Icons.notes_outlined,
                textInputAction: TextInputAction.done,
              ),

              const SizedBox(height: AppSpacing.xl),

              AppButton(
                label: 'Registrar evento',
                prefixIcon: Icons.add_circle_outline,
                isLoading: _saving,
                onPressed:
                    (_saving || _loadingVisitors || _selectedVisitorId == null)
                    ? null
                    : _save,
              ),
              const SizedBox(height: AppSpacing.base),
            ],
          ),
        ),
      ),
    );
  }
}
