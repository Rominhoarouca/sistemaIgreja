import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geocoding/geocoding.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../widgets/attendance_calendar_dialog.dart';
import '../widgets/attendee_widgets.dart';
import '../../../../shared/widgets/cep_address_fields.dart';
import '../../../dashboard/presentation/widgets/demographic_fields.dart';
import 'leader_dashboard_view.dart';
import '../../../../injection/injection.dart';
import '../../../../shared/widgets/app_map_tiles.dart';
import '../../../../shared/utils/profile_photo.dart';
import '../../../../shared/utils/route_aware_reload.dart';
import '../../../../shared/utils/phone_input.dart';
import '../../../../shared/widgets/cell_type_badge.dart';

/// Show a snackbar above any modal sheet by using the root navigator's context.
void _showTopSnackBar(
  BuildContext context,
  String message, {
  Color backgroundColor = AppColors.error,
}) {
  final rootCtx = Navigator.of(context, rootNavigator: true).context;
  ScaffoldMessenger.maybeOf(rootCtx)
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
}

// ─── Cell menu item data ─────────────────────────────────────────────────────
class _CellMenuItem {
  const _CellMenuItem({
    required this.id,
    required this.name,
    this.typeName,
    this.typeId,
    required this.dayOfWeek,
    required this.time,
  });

  final String id;
  final String name;
  final String? typeName;
  final String? typeId;
  final String dayOfWeek;
  final String time;

  factory _CellMenuItem.fromJson(Map<String, dynamic> json) => _CellMenuItem(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    typeName: json['cellTypeName'] as String?,
    typeId: json['cellTypeId'] as String?,
    dayOfWeek: json['dayOfWeek'] as String? ?? '',
    time: json['time'] as String? ?? '',
  );

  String get dayLabel => switch (dayOfWeek) {
    'segunda' => 'Seg',
    'terca' => 'Ter',
    'quarta' => 'Qua',
    'quinta' => 'Qui',
    'sexta' => 'Sex',
    'sabado' => 'Sáb',
    'domingo' => 'Dom',
    _ => dayOfWeek,
  };
}

/// Leader Panel — main hub for cell leaders
/// Shows: forwarded visitors, attendance, materials, spiritual history
class LeaderHomePage extends StatefulWidget {
  const LeaderHomePage({super.key});

  @override
  State<LeaderHomePage> createState() => _LeaderHomePageState();
}

class _LeaderHomePageState extends State<LeaderHomePage>
    with RouteAwareReload<LeaderHomePage> {
  @override
  void onRouteReturn() => _loadCells();

  int _selectedTab = 0;
  String? _coordenacaoName;
  Color? _coordenacaoColor;

  // Cell menu state
  List<_CellMenuItem> _cells = [];
  _CellMenuItem? _selectedCell;
  bool _loadingCells = true;

  @override
  void initState() {
    super.initState();
    _loadCoordInfo();
    _loadCells();
  }

  Future<void> _loadCells() async {
    try {
      final dio = getIt<DioClient>().dio;
      final resp = await dio.get('/cells/my-cell');
      final cellsRaw =
          (resp.data as Map<String, dynamic>)['cells'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _cells = cellsRaw
            .map((c) => _CellMenuItem.fromJson(c as Map<String, dynamic>))
            .toList();
        _loadingCells = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingCells = false);
    }
  }

  Future<void> _loadCoordInfo() async {
    try {
      final dio = getIt<DioClient>().dio;
      final resp = await dio.get('/users/me');
      final user =
          (resp.data as Map<String, dynamic>)['user'] as Map<String, dynamic>?;
      if (user == null || !mounted) return;
      final colorHex = user['coordenacaoColor'] as String?;
      final name = user['coordenacaoName'] as String?;
      if (colorHex != null && name != null) {
        setState(() {
          _coordenacaoName = name;
          _coordenacaoColor = Color(
            int.parse(colorHex.replaceFirst('#', '0xFF')),
          );
        });
      }
    } catch (_) {
      // Non-fatal — banner just won't show
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;

    // ── Loading cells ───────────────────────────────────────────────────────
    if (_loadingCells) {
      return Scaffold(
        appBar: AppBar(title: const Text('Painel do Líder')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // ── Home: dashboard agregado das células do líder ────────────────────
    if (_selectedCell == null) {
      return LeaderDashboardView(
        cells: _cells
            .map(
              (c) => LeaderCellInfo(
                id: c.id,
                name: c.name,
                dayLabel: c.dayLabel,
                time: c.time,
                typeName: c.typeName,
              ),
            )
            .toList(),
        coordenacaoName: _coordenacaoName,
        coordenacaoColor: _coordenacaoColor,
        onNavigateTab: (tab) {
          if (_cells.isEmpty) return;
          setState(() {
            _selectedCell = _cells.first;
            _selectedTab = tab;
          });
        },
        onOpenCell: (info, {int tab = 0}) {
          final cell = _cells.firstWhere((c) => c.id == info.id);
          setState(() {
            _selectedCell = cell;
            _selectedTab = tab;
          });
        },
      );
    }

    // ── Cell detail: tabs scoped to selected cell ───────────────────────────
    final cell = _selectedCell!;

    final appBar = AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(cell.name, style: AppTypography.titleSmall),
          if (CellTypeBadge.has(cell.typeName))
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: CellTypeBadge(typeName: cell.typeName),
            ),
        ],
      ),
      leading: IconButton(
        tooltip: 'Voltar ao painel',
        icon: const Icon(Icons.arrow_back),
        onPressed: () => setState(() => _selectedCell = null),
      ),
      actions: [
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
      key: ValueKey(cell.id),
      index: _selectedTab,
      children: [
        _AttendeesTab(
          cellId: cell.id,
          onOpenAttendance: () => setState(() => _selectedTab = 1),
        ),
        _AttendanceTab(cellId: cell.id),
        _MaterialsTab(cellId: cell.id),
        _SpiritualHistoryTab(cellId: cell.id),
      ],
    );

    final coordBanner = _coordenacaoColor != null
        ? Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePaddingH,
              vertical: AppSpacing.xs,
            ),
            color: _coordenacaoColor!.withValues(alpha: 0.15),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _coordenacaoColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _coordenacaoName ?? '',
                  style: AppTypography.labelSmall.copyWith(
                    color: _coordenacaoColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
        : null;

    final bodyWithBanner = coordBanner != null
        ? Column(
            children: [
              coordBanner,
              Expanded(child: tabContent),
            ],
          )
        : tabContent;

    if (isWide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedTab + 1,
              onDestinationSelected: (i) => setState(() {
                if (i == 0) {
                  _selectedCell = null; // volta ao dashboard
                } else {
                  _selectedTab = i - 1;
                }
              }),
              labelType: NavigationRailLabelType.all,
              destinations: leaderRailDestinations(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: bodyWithBanner),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: bodyWithBanner,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab + 1,
        onDestinationSelected: (i) => setState(() {
          if (i == 0) {
            _selectedCell = null; // volta ao dashboard
          } else {
            _selectedTab = i - 1;
          }
        }),
        destinations: kLeaderNavDestinations,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 1: FREQUENTADORES (membros + visitantes)
// ═══════════════════════════════════════════════════════════════════════════

class _AttendeesTab extends StatefulWidget {
  const _AttendeesTab({required this.cellId, required this.onOpenAttendance});

  final String cellId;

  /// Abre a aba Presença — usado pelo "Mais reuniões".
  final VoidCallback onOpenAttendance;

  @override
  State<_AttendeesTab> createState() => _AttendeesTabState();
}

/// Membros e visitantes da célula em uma lista só. O que diferencia é a badge,
/// e o filtro permite isolar um dos dois grupos.
class _AttendeesTabState extends State<_AttendeesTab>
    with RouteAwareReload<_AttendeesTab> {
  @override
  void onRouteReturn() => _loadData();

  late final Dio _dio;
  final _searchCtrl = TextEditingController();
  String _query = '';
  AttendeeFilter _filter = AttendeeFilter.all;
  bool _loading = true;
  String? _error;
  List<CellAttendee> _attendees = [];
  List<CellMeetingSummary> _meetings = [];

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
        _dio.get('/attendance/cell/${widget.cellId}/attendees'),
        _dio.get('/attendance/cell/${widget.cellId}/meetings'),
      ]);
      final attendees =
          (results[0].data as Map<String, dynamic>)['attendees'] as List? ?? [];
      final meetings =
          (results[1].data as Map<String, dynamic>)['meetings'] as List? ?? [];

      if (!mounted) return;
      setState(() {
        _attendees = attendees
            .map((e) => CellAttendee.fromJson(e as Map<String, dynamic>))
            .toList();
        _meetings = meetings
            .map((e) => CellMeetingSummary.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar frequentadores';
        _loading = false;
      });
    }
  }

  List<CellAttendee> get _filtered {
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

  Future<void> _openDetails(CellAttendee attendee) async {
    var memberChanged = false;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => attendee.isMember
          ? _MemberDetailSheet(
              member: attendee,
              dio: _dio,
              cellId: widget.cellId,
              onChanged: () => memberChanged = true,
            )
          : _VisitorDetailSheet(
              visitor: _VisitorData.fromAttendee(attendee, widget.cellId),
              dio: _dio,
              cellId: widget.cellId,
            ),
    );
    if (changed == true || memberChanged) _loadData();
  }

  /// Duas origens de cadastro (visitante e membro) atrás de um único botão.
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
          ? _NewVisitorSheet(dio: _dio, cellId: widget.cellId)
          : _AddMemberSheet(dio: _dio, cellId: widget.cellId),
    );
    if (created == true) _loadData();
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

    final meetingsCard = LastMeetingsCard(
      meetings: _meetings,
      onSeeAll: widget.onOpenAttendance,
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Acima de 1000px cabe a coluna de reuniões ao lado, como no
            // layout de referência; abaixo ela vai para o fim da lista.
            final isWide = constraints.maxWidth >= 1000;
            if (!isWide) {
              return ListView(
                padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
                children: [
                  ..._buildListSection(),
                  const SizedBox(height: AppSpacing.xl),
                  meetingsCard,
                  const SizedBox(height: AppSpacing.xl2),
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
                    children: [
                      ..._buildListSection(),
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
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOptions,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Adicionar'),
      ),
    );
  }

  List<Widget> _buildListSection() {
    final filtered = _filtered;
    return [
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
      AppCollapsibleSection(
        title: 'Frequentadores (${filtered.length})',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (filtered.isEmpty)
              AppEmptyState(
                title: _query.isNotEmpty || _filter != AttendeeFilter.all
                    ? 'Nada encontrado'
                    : 'Ninguém na célula ainda',
                subtitle: _query.isNotEmpty || _filter != AttendeeFilter.all
                    ? 'Ajuste a busca ou o filtro.'
                    : 'Cadastre um visitante ou adicione um membro pelo botão '
                          'abaixo.',
                icon: Icons.groups_outlined,
              )
            else
              for (final attendee in filtered) ...[
                AttendeeCard(
                  attendee: attendee,
                  onTap: () => _openDetails(attendee),
                  onFrequencyTap: () => showAttendanceCalendarDialog(
                    context: context,
                    dio: _dio,
                    cellId: widget.cellId,
                    attendee: attendee,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
          ],
        ),
      ),
    ];
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
  final String? photoUrl;
  final bool isBaptized;

  const _VisitorData(
    this.id,
    this.name,
    this.status,
    this.cellId,
    this.memberId,
    this.time,
    this.phone,
    this.neighborhood,
    this.address, [
    this.photoUrl,
    this.isBaptized = false,
  ]);

  /// `memberId` é sempre nulo aqui: a lista de frequentadores já exclui os
  /// visitantes convertidos em membro, senão a pessoa apareceria duas vezes.
  factory _VisitorData.fromAttendee(CellAttendee attendee, String cellId) =>
      _VisitorData(
        attendee.id,
        attendee.name,
        attendee.status ?? 'novo',
        cellId,
        null,
        _relativeTime(attendee.createdAt),
        attendee.phone ?? 'Nao informado',
        attendee.neighborhood ?? 'Nao informado',
        attendee.address ?? 'Nao informado',
        attendee.photoUrl,
        attendee.isBaptized == true,
      );

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
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.dio.post(
        '/visitors',
        data: {
          'name': _nameCtrl.text.trim(),
          'phone': _phoneCtrl.text.trim(),
          if (_addressValue.address.isNotEmpty)
            'address': _addressValue.address,
          if (_addressValue.numero.isNotEmpty) 'numero': _addressValue.numero,
          if (_addressValue.complemento != null)
            'complemento': _addressValue.complemento,
          if (_addressValue.bairroId != null)
            'bairroId': _addressValue.bairroId,
          if (_gender != null) 'gender': _gender,
          if (_birthDate != null) 'birthDate': apiBirthDate(_birthDate),
          if (_maritalStatus != null) 'maritalStatus': _maritalStatus,
          if (widget.cellId != null) 'cellId': widget.cellId,
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
            'Erro ao cadastrar visitante',
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
                  inputFormatters: brPhoneInputFormatters,
                  decoration: const InputDecoration(
                    labelText: 'Telefone *',
                    hintText: '(11) 99999-9999',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().length < 8)
                      ? 'Informe o telefone'
                      : null,
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

/// Avatar com badge de câmera — usado nas fichas de membro e de visitante.
class _PhotoAvatar extends StatelessWidget {
  const _PhotoAvatar({
    required this.initials,
    required this.photoUrl,
    required this.busy,
    required this.onTap,
  });

  final String initials;
  final String? photoUrl;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          AppAvatar(initials: initials, imageUrl: photoUrl, size: 56),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: busy
                  ? const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.white,
                      ),
                    )
                  : const Icon(
                      Icons.photo_camera_outlined,
                      size: 12,
                      color: AppColors.white,
                    ),
            ),
          ),
        ],
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
  late String? _photoUrl = widget.visitor.photoUrl;
  late bool _isBaptized = widget.visitor.isBaptized;
  bool _uploadingPhoto = false;
  bool _savingBaptism = false;

  Future<void> _setBaptized(bool value) async {
    if (_savingBaptism) return;
    final previous = _isBaptized;
    setState(() {
      _isBaptized = value;
      _savingBaptism = true;
    });
    try {
      await widget.dio.patch(
        '/visitors/${widget.visitor.id}/baptism',
        data: {'isBaptized': value},
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isBaptized = previous);
      _showTopSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Não foi possível alterar o batismo',
      );
    } finally {
      if (mounted) setState(() => _savingBaptism = false);
    }
  }

  Future<void> _changePhoto() async {
    final photo = await pickProfilePhoto(context);
    if (photo == null || !mounted) return;

    setState(() => _uploadingPhoto = true);
    try {
      final form = FormData.fromMap({
        'photo': MultipartFile.fromBytes(photo.bytes, filename: photo.filename),
      });
      final resp = await widget.dio.post(
        '/visitors/${widget.visitor.id}/photo',
        data: form,
      );
      if (!mounted) return;
      setState(() {
        _photoUrl = (resp.data as Map<String, dynamic>)['photoUrl'] as String?;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      _showTopSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Não foi possível enviar a foto',
      );
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }
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
      _showTopSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao atualizar célula',
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
      _showTopSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao atualizar status',
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
      _showTopSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao converter visitante em membro',
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
                  _PhotoAvatar(
                    initials: widget.visitor.name
                        .split(' ')
                        .map((e) => e[0])
                        .take(2)
                        .join(),
                    photoUrl: _photoUrl,
                    busy: _uploadingPhoto,
                    onTap: _uploadingPhoto ? null : _changePhoto,
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

              // Registrar "Batizado" no histórico também liga esta chave.
              AppCard(
                padding: EdgeInsets.zero,
                child: SwitchListTile(
                  secondary: const Icon(Icons.water_drop_outlined),
                  title: Text('Batizado', style: AppTypography.bodyMedium),
                  value: _isBaptized,
                  onChanged: _savingBaptism ? null : _setBaptized,
                ),
              ),

              const SizedBox(height: AppSpacing.base),

              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.phone_outlined,
                      label: 'Telefone',
                      value: formatBrPhone(widget.visitor.phone),
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
                      appTileLayer(),
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
// DETALHE DE MEMBRO
// ═══════════════════════════════════════════════════════════════════════════

/// Detalhes de um membro de célula. Visitante usa [_VisitorDetailSheet], que
/// tem as ações do funil de acompanhamento — membro não precisa delas.
class _MemberDetailSheet extends StatefulWidget {
  const _MemberDetailSheet({
    required this.member,
    required this.dio,
    required this.cellId,
    required this.onChanged,
  });

  final CellAttendee member;
  final Dio dio;
  final String cellId;

  /// Avisa o caller que função/foto mudaram. É callback e não resultado do
  /// `pop` porque o sheet também fecha por arrasto, sem passar por `pop`.
  final VoidCallback onChanged;

  @override
  State<_MemberDetailSheet> createState() => _MemberDetailSheetState();
}

class _MemberDetailSheetState extends State<_MemberDetailSheet> {
  late String _roleInCell = widget.member.roleInCell;
  late String? _photoUrl = widget.member.photoUrl;
  late bool _isBaptized = widget.member.isBaptized == true;
  bool _busy = false;

  CellAttendee get member => widget.member;

  static const _roleOptions = [
    ('MEMBRO', 'Membro'),
    ('VICE_LIDER', 'Vice-líder'),
    ('ANFITRIAO', 'Anfitrião'),
  ];

  String get _genderLabel => switch (member.gender) {
    'MASCULINO' => 'Masculino',
    'FEMININO' => 'Feminino',
    _ => 'Não informado',
  };

  Future<void> _setRole(String role) async {
    if (role == _roleInCell || _busy) return;
    final previous = _roleInCell;
    setState(() {
      _roleInCell = role;
      _busy = true;
    });
    try {
      await widget.dio.patch(
        '/cells/${widget.cellId}/members/${member.id}',
        data: {'roleInCell': role},
      );
      widget.onChanged();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _roleInCell = previous);
      _showTopSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Não foi possível alterar a função',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setBaptized(bool value) async {
    if (_busy) return;
    final previous = _isBaptized;
    setState(() {
      _isBaptized = value;
      _busy = true;
    });
    try {
      await widget.dio.patch(
        '/cells/${widget.cellId}/members/${member.id}',
        data: {'isBaptized': value},
      );
      widget.onChanged();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isBaptized = previous);
      _showTopSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Não foi possível alterar o batismo',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePhoto() async {
    final photo = await pickProfilePhoto(context);
    if (photo == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final form = FormData.fromMap({
        'photo': MultipartFile.fromBytes(photo.bytes, filename: photo.filename),
      });
      final resp = await widget.dio.post(
        '/cells/${widget.cellId}/members/${member.id}/photo',
        data: form,
      );
      if (!mounted) return;
      setState(() {
        _photoUrl = (resp.data as Map<String, dynamic>)['photoUrl'] as String?;
      });
      widget.onChanged();
    } on DioException catch (e) {
      if (!mounted) return;
      _showTopSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Não foi possível enviar a foto',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final address = member.address;
    final hasAddress = address != null && address.isNotEmpty;
    final locality = [
      member.neighborhood,
      member.city,
    ].where((p) => p != null && p.isNotEmpty).join(' · ');

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
                  // Toque na foto troca a imagem.
                  _PhotoAvatar(
                    initials: member.initials,
                    photoUrl: _photoUrl,
                    busy: _busy,
                    onTap: _busy ? null : _changePhoto,
                  ),
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
              Text('Função na célula', style: AppTypography.titleSmall),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final (value, label) in _roleOptions)
                    ChoiceChip(
                      label: Text(label),
                      selected: _roleInCell == value,
                      onSelected: _busy ? null : (_) => _setRole(value),
                    ),
                ],
              ),

              const SizedBox(height: AppSpacing.base),
              // Registrar "Batizado" no histórico também marca aqui.
              AppCard(
                padding: EdgeInsets.zero,
                child: SwitchListTile(
                  secondary: const Icon(Icons.water_drop_outlined),
                  title: Text('Batizado', style: AppTypography.bodyMedium),
                  value: _isBaptized,
                  onChanged: _busy ? null : _setBaptized,
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.insights_outlined,
                      label: 'Frequência',
                      value: member.meetingsCount == 0
                          ? 'Sem presença registrada'
                          : '${formatPercentBr(member.attendanceRate)} '
                                '(${member.presentCount} de ${member.meetingsCount} encontros)',
                    ),
                    const Divider(height: 1),
                    _DetailRow(
                      icon: Icons.phone_outlined,
                      label: 'Telefone',
                      value: member.phone?.isNotEmpty == true
                          ? formatBrPhone(member.phone!)
                          : 'Não informado',
                    ),
                    const Divider(height: 1),
                    _DetailRow(
                      icon: Icons.email_outlined,
                      label: 'E-mail',
                      value: member.email?.isNotEmpty == true
                          ? member.email!
                          : 'Não informado',
                    ),
                    const Divider(height: 1),
                    _DetailRow(
                      icon: Icons.cake_outlined,
                      label: 'Aniversário',
                      value: member.birthDate != null
                          ? formatDateBr(member.birthDate!.toLocal())
                          : 'Não informado',
                    ),
                    const Divider(height: 1),
                    _DetailRow(
                      icon: Icons.favorite_outline,
                      label: 'Estado civil',
                      value: member.maritalStatus?.isNotEmpty == true
                          ? member.maritalStatus!
                          : 'Não informado',
                    ),
                    const Divider(height: 1),
                    _DetailRow(
                      icon: Icons.wc_outlined,
                      label: 'Gênero',
                      value: _genderLabel,
                    ),
                    const Divider(height: 1),
                    if (hasAddress)
                      _TappableDetailRow(
                        icon: Icons.location_on_outlined,
                        label: 'Endereço',
                        value: locality.isEmpty
                            ? address
                            : '$address — $locality',
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
                              address: address,
                              visitorName: member.name,
                            ),
                          );
                        },
                      )
                    else
                      _DetailRow(
                        icon: Icons.location_on_outlined,
                        label: 'Endereço',
                        value: 'Não informado',
                      ),
                    const Divider(height: 1),
                    _DetailRow(
                      icon: Icons.access_time_outlined,
                      label: 'Membro desde',
                      value: formatDateBr(member.createdAt.toLocal()),
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
  CepAddressValue _addressValue = const CepAddressValue(
    address: '',
    numero: '',
    complemento: null,
    bairroId: null,
  );
  bool _isBaptized = false;
  String? _gender;
  DateTime? _birthDate;
  String? _maritalStatus;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
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
          // CellMember só tem um campo `address` — número/complemento entram
          // concatenados, diferente de Visitor (que tem colunas próprias).
          if (!_addressValue.isEmpty) 'address': _addressValue.combined,
          if (_addressValue.bairroId != null)
            'bairroId': _addressValue.bairroId,
          if (_gender != null) 'gender': _gender,
          if (_birthDate != null) 'birthDate': apiBirthDate(_birthDate),
          if (_maritalStatus != null) 'maritalStatus': _maritalStatus,
          'isBaptized': _isBaptized,
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
    // O formulário é mais alto que o sheet quando o teclado abre; sem o
    // scroll os últimos campos e o botão de salvar ficavam inalcançáveis.
    return SingleChildScrollView(
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
              hint: '(11) 99999-9999',
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              inputFormatters: brPhoneInputFormatters,
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
              onMaritalStatusChanged: (v) => setState(() => _maritalStatus = v),
            ),
            const SizedBox(height: AppSpacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.water_drop_outlined),
              title: Text('Já é batizado', style: AppTypography.bodyMedium),
              value: _isBaptized,
              onChanged: (v) => setState(() => _isBaptized = v),
            ),
            const SizedBox(height: AppSpacing.base),
            AppButton(
              label: _saving ? 'Salvando...' : 'Salvar',
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
  const _AttendanceTab({required this.cellId});

  final String cellId;

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab>
    with RouteAwareReload<_AttendanceTab> {
  @override
  void onRouteReturn() => _loadData();

  late final Dio _dio;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _meetings = [];

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
      final meetingsResp = await _dio.get(
        '/attendance/cell/${widget.cellId}/meetings',
      );
      final meetings =
          ((meetingsResp.data as Map<String, dynamic>)['meetings'] as List)
              .cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
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
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NewMeetingSheet(dio: _dio, cellId: widget.cellId),
    ).then((created) {
      if (created == true) _loadData();
    });
  }

  Future<void> _openMeetingDetails(Map<String, dynamic> meeting) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MeetingAttendanceSheet(
        dio: _dio,
        cellId: widget.cellId,
        meetingDateIso: meeting['meetingDate'] as String,
        lesson: meeting['lesson'] as String?,
        ministrante: meeting['ministrante'] as String?,
        materialId: meeting['materialId'] as String?,
        materialTitle: meeting['materialTitle'] as String?,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;
    final labelStyle = AppTypography.bodySmall.copyWith(color: mutedColor);

    final summary = CellMeetingSummary.fromJson(meeting);
    final total = (meeting['total'] as num?)?.toInt() ?? 0;
    final pct = total > 0 ? (summary.present / total * 100).round() : 0;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event_available_outlined,
                color: isDark ? AppColors.linkDark : AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Encontro de ${formatDateBr(summary.meetingDate)}',
                  style: AppTypography.titleSmall,
                ),
              ),
              AppBadge(
                label: summary.isRecorded ? 'Realizada' : 'Pendente',
                variant: summary.isRecorded
                    ? AppBadgeVariant.success
                    : AppBadgeVariant.warning,
                size: AppBadgeSize.sm,
              ),
            ],
          ),
          Padding(
            // Alinha o corpo com o título, depois do ícone.
            padding: const EdgeInsets.only(left: 36, top: AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (summary.lesson != null)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Lição: ', style: labelStyle),
                        TextSpan(
                          text: summary.lesson,
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                if (summary.ministrante != null)
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: 'Ministrante: ', style: labelStyle),
                        TextSpan(
                          text: summary.ministrante,
                          style: AppTypography.bodySmall,
                        ),
                      ],
                    ),
                  ),
                if (summary.lesson != null || summary.ministrante != null)
                  const SizedBox(height: AppSpacing.xs),
                Text(
                  total == 0
                      ? 'Presença ainda não registrada'
                      : '${summary.present} de $total presentes ($pct%) · '
                            'membros ${summary.membersPresent} · '
                            'visitantes ${summary.visitorsPresent}',
                  style: labelStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Photo Section Widget
// ─────────────────────────────────────────────────────────────────────────────

class _PhotoSection extends StatelessWidget {
  const _PhotoSection({
    required this.photoBytes,
    required this.existingPhotoUrl,
    required this.onPick,
    required this.onRemove,
  });

  /// Bytes da foto recém-escolhida. Guardamos os bytes em vez de um caminho de
  /// arquivo porque `dart:io` não existe no Flutter web, onde o app roda como
  /// PWA — `Image.file` deixaria o preview em branco no navegador.
  final Uint8List? photoBytes;
  final String? existingPhotoUrl;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  void _openViewer(BuildContext context, {Uint8List? bytes, String? url}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        // fullscreenDialog dá o botão de fechar e o gesto/back nativo.
        fullscreenDialog: true,
        builder: (_) => _MeetingPhotoViewer(bytes: bytes, url: url),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // New photo selected locally
    if (photoBytes != null) {
      return AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ZoomableThumb(
              onTap: () => _openViewer(context, bytes: photoBytes),
              child: Image.memory(
                photoBytes!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.photo_outlined,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Foto do encontro selecionada',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Remover'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    onPressed: onRemove,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Already has photo saved in server
    if (existingPhotoUrl != null) {
      return AppCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ZoomableThumb(
              onTap: () => _openViewer(context, url: existingPhotoUrl),
              child: Image.network(
                existingPhotoUrl!,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 80,
                  child: Center(child: Icon(Icons.broken_image_outlined)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Foto do encontro',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Trocar'),
                    onPressed: onPick,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // No photo yet
    return OutlinedButton.icon(
      icon: const Icon(Icons.add_a_photo_outlined),
      label: const Text('Adicionar foto do encontro (opcional)'),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.sm),
        ),
      ),
      onPressed: onPick,
    );
  }
}

/// Miniatura clicável da foto do encontro, com dica visual de que amplia.
class _ZoomableThumb extends StatelessWidget {
  const _ZoomableThumb({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      child: Stack(
        children: [
          child,
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(onTap: onTap),
            ),
          ),
          Positioned(
            right: AppSpacing.sm,
            bottom: AppSpacing.sm,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                ),
                child: const Icon(
                  Icons.zoom_out_map,
                  size: 18,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Foto do encontro em tela cheia, com pinch/scroll para ampliar.
class _MeetingPhotoViewer extends StatelessWidget {
  const _MeetingPhotoViewer({this.bytes, this.url});

  final Uint8List? bytes;
  final String? url;

  @override
  Widget build(BuildContext context) {
    final Widget image = bytes != null
        ? Image.memory(bytes!, fit: BoxFit.contain)
        : Image.network(
            url!,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                size: AppSpacing.iconXl,
                color: AppColors.white,
              ),
            ),
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : const Center(
                    child: CircularProgressIndicator(color: AppColors.white),
                  ),
          );

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.white,
        elevation: 0,
        title: Text('Foto do encontro', style: AppTypography.titleSmall),
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(child: image),
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
  final _lessonCtrl = TextEditingController();
  final _ministranteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _lessonCtrl.dispose();
    _ministranteCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _saving = true);
    try {
      await widget.dio.post(
        '/attendance/cell/${widget.cellId}/meetings',
        data: {
          'meetingDate': _selectedDate.toIso8601String(),
          'lesson': _lessonCtrl.text.trim(),
          'ministrante': _ministranteCtrl.text.trim(),
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
            'Erro ao criar encontro',
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
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _lessonCtrl,
                label: 'Lição (opcional)',
                hint: 'Tema ministrado no encontro',
                prefixIcon: Icons.menu_book_outlined,
                maxLines: 2,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _ministranteCtrl,
                label: 'Ministrante (opcional)',
                hint: 'Quem ministrou',
                prefixIcon: Icons.person_outline,
                textInputAction: TextInputAction.done,
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
      ),
    );
  }
}

/// Material do acervo da célula. A API já devolve do mais recente para o mais
/// antigo, então a ordem da lista é a ordem de exibição.
class _MaterialOption {
  const _MaterialOption({
    required this.id,
    required this.title,
    required this.uploadedAt,
  });

  final String id;
  final String title;
  final DateTime? uploadedAt;

  /// Sentinela de "nenhum material" — distingue "limpou" de "fechou o sheet".
  static const none = _MaterialOption(id: '', title: '', uploadedAt: null);

  factory _MaterialOption.fromJson(Map<String, dynamic> j) => _MaterialOption(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    uploadedAt: DateTime.tryParse(j['uploadedAt'] as String? ?? ''),
  );
}

/// Quem pode ter ministrado: líder, membros (com o papel na célula) e
/// visitantes.
class _MinistranteOption {
  const _MinistranteOption({required this.name, required this.role});

  final String name;
  final String role;

  factory _MinistranteOption.fromJson(Map<String, dynamic> j) =>
      _MinistranteOption(
        name: j['name'] as String? ?? '',
        role: j['role'] as String? ?? 'MEMBRO',
      );

  String get roleLabel => switch (role) {
    'LIDER' => 'Líder',
    'VICE_LIDER' => 'Vice-líder',
    'ANFITRIAO' => 'Anfitrião',
    'VISITANTE' => 'Visitante',
    _ => 'Membro',
  };

  AppBadgeVariant get roleVariant => switch (role) {
    'LIDER' => AppBadgeVariant.primary,
    'VICE_LIDER' => AppBadgeVariant.info,
    'ANFITRIAO' => AppBadgeVariant.success,
    'VISITANTE' => AppBadgeVariant.warning,
    _ => AppBadgeVariant.neutral,
  };
}

/// Escolha do material usado como lição, com busca. A lista já vem ordenada
/// da API (mais recente primeiro).
class _MaterialPickerSheet extends StatefulWidget {
  const _MaterialPickerSheet({required this.materials, this.selectedId});

  final List<_MaterialOption> materials;
  final String? selectedId;

  @override
  State<_MaterialPickerSheet> createState() => _MaterialPickerSheetState();
}

class _MaterialPickerSheetState extends State<_MaterialPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.materials
        .where((m) => m.title.toLowerCase().contains(_query.toLowerCase()))
        .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Material da lição', style: AppTypography.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              AppSearchField(
                hint: 'Buscar material...',
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: AppSpacing.sm),
              ListTile(
                leading: const Icon(Icons.block_outlined),
                title: const Text('Nenhum material'),
                subtitle: const Text('Escrever a lição à mão'),
                onTap: () =>
                    Navigator.of(context).pop(_MaterialOption.none),
              ),
              const Divider(height: 1),
              Flexible(
                child: filtered.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Text(
                          'Nenhum material encontrado',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final material = filtered[i];
                          final selected = material.id == widget.selectedId;
                          return ListTile(
                            leading: const Icon(Icons.description_outlined),
                            title: Text(material.title),
                            subtitle: material.uploadedAt == null
                                ? null
                                : Text(formatDateBr(material.uploadedAt!)),
                            trailing: selected
                                ? const Icon(
                                    Icons.check_circle,
                                    color: AppColors.success,
                                  )
                                : null,
                            onTap: () => Navigator.of(context).pop(material),
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
}

/// Escolha do ministrante entre os participantes da célula.
class _MinistrantePickerSheet extends StatelessWidget {
  const _MinistrantePickerSheet({required this.options});

  final List<_MinistranteOption> options;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quem ministrou', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: options.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final option = options[i];
                  return ListTile(
                    title: Text(option.name),
                    trailing: AppBadge(
                      label: option.roleLabel,
                      variant: option.roleVariant,
                      size: AppBadgeSize.sm,
                    ),
                    onTap: () => Navigator.of(context).pop(option),
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

class _MeetingAttendanceSheet extends StatefulWidget {
  const _MeetingAttendanceSheet({
    required this.dio,
    required this.cellId,
    required this.meetingDateIso,
    this.lesson,
    this.ministrante,
    this.materialId,
    this.materialTitle,
  });

  final Dio dio;
  final String cellId;
  final String meetingDateIso;

  /// Valores atuais do encontro, para pré-preencher os campos editáveis.
  final String? lesson;
  final String? ministrante;

  /// Material do acervo já associado como lição, quando houver.
  final String? materialId;
  final String? materialTitle;

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

  // Optional photo for this meeting
  XFile? _photo;
  Uint8List? _photoBytes;
  String? _existingPhotoUrl;

  late final TextEditingController _lessonCtrl;
  late final TextEditingController _ministranteCtrl;
  late final String _initialLesson;
  late final String _initialMinistrante;

  /// Acervo da célula, do mais recente para o mais antigo (ordem que a API
  /// devolve), e quem pode ter ministrado.
  List<_MaterialOption> _materials = const [];
  List<_MinistranteOption> _ministrantes = const [];
  String? _materialId;
  String? _materialTitle;
  late final String? _initialMaterialId;

  /// A lista costuma ser longa; começa aberta só quando ninguém foi marcado
  /// ainda, que é o caso em que o líder precisa mexer nela.
  bool _participantsExpanded = true;

  @override
  void initState() {
    super.initState();
    _initialLesson = widget.lesson?.trim() ?? '';
    _initialMinistrante = widget.ministrante?.trim() ?? '';
    _initialMaterialId = widget.materialId;
    _materialId = widget.materialId;
    _materialTitle = widget.materialTitle;
    _lessonCtrl = TextEditingController(text: _initialLesson);
    _ministranteCtrl = TextEditingController(text: _initialMinistrante);
    _loadInitialData();
  }

  @override
  void dispose() {
    _lessonCtrl.dispose();
    _ministranteCtrl.dispose();
    super.dispose();
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
        widget.dio.get(
          '/attendance/cell/${widget.cellId}/meetings/${Uri.encodeComponent(widget.meetingDateIso)}/photo',
        ),
      ]);

      final visitorsResp = results[0];
      final membersResp = results[1];
      final attendanceResp = results[2];
      final photoResp = results[3];

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
        _existingPhotoUrl =
            (photoResp.data as Map<String, dynamic>)['photoUrl'] as String?;
        _participantsExpanded = presentIds.isEmpty;
        _loading = false;
      });
      // Auxiliares: se falharem, o líder ainda escreve lição e ministrante à mão.
      await _loadPickerOptions();
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

  /// Acervo de materiais da célula e possíveis ministrantes. Nenhum dos dois
  /// é obrigatório para salvar o encontro, então falha aqui é silenciosa.
  Future<void> _loadPickerOptions() async {
    try {
      final results = await Future.wait([
        widget.dio.get(
          '/materials',
          queryParameters: {'cellId': widget.cellId},
        ),
        widget.dio.get('/attendance/cell/${widget.cellId}/ministrantes'),
      ]);

      final materials =
          ((results[0].data as Map<String, dynamic>)['materials'] as List? ?? [])
              .cast<Map<String, dynamic>>()
              .map(_MaterialOption.fromJson)
              .toList();
      final ministrantes =
          ((results[1].data as Map<String, dynamic>)['options'] as List? ?? [])
              .cast<Map<String, dynamic>>()
              .map(_MinistranteOption.fromJson)
              .toList();

      if (!mounted) return;
      setState(() {
        _materials = materials;
        _ministrantes = ministrantes;
        // O título só chega junto do encontro; se não veio, resolve pelo acervo.
        if (_materialTitle == null && _materialId != null) {
          _materialTitle = materials
              .where((m) => m.id == _materialId)
              .map((m) => m.title)
              .firstOrNull;
        }
      });
    } catch (_) {
      // Sem acervo/lista: os campos de texto continuam funcionando.
    }
  }

  Future<void> _pickMaterial() async {
    final selected = await showModalBottomSheet<_MaterialOption?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MaterialPickerSheet(
        materials: _materials,
        selectedId: _materialId,
      ),
    );
    // `null` = fechou sem escolher. A opção "nenhum" devolve o sentinela.
    if (selected == null || !mounted) return;
    setState(() {
      if (selected.id.isEmpty) {
        _materialId = null;
        _materialTitle = null;
      } else {
        _materialId = selected.id;
        _materialTitle = selected.title;
      }
    });
  }

  Future<void> _pickMinistrante() async {
    final selected = await showModalBottomSheet<_MinistranteOption>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MinistrantePickerSheet(options: _ministrantes),
    );
    if (selected == null || !mounted) return;
    // Grava o nome: `ministrante` é texto livre no banco, pode ser alguém de
    // fora da célula digitado à mão.
    setState(() => _ministranteCtrl.text = selected.name);
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

    final lesson = _lessonCtrl.text.trim();
    final ministrante = _ministranteCtrl.text.trim();
    final detailsChanged =
        lesson != _initialLesson ||
        ministrante != _initialMinistrante ||
        _materialId != _initialMaterialId;

    if (changedParticipants.isEmpty && _photo == null && !detailsChanged) {
      if (!mounted) return;
      Navigator.of(context).pop(false);
      return;
    }

    setState(() => _saving = true);
    try {
      // 1. Save attendance changes
      if (changedParticipants.isNotEmpty) {
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
      }

      // 2. Lição e ministrante. O POST faz upsert, então também funciona para
      //    encontros que só existem como presença lançada (sem cell_meetings).
      if (detailsChanged) {
        await widget.dio.post(
          '/attendance/cell/${widget.cellId}/meetings',
          data: {
            'meetingDate': widget.meetingDateIso,
            'lesson': lesson,
            'ministrante': ministrante,
            'materialId': _materialId,
          },
        );
      }

      // 3. Upload photo if selected
      if (_photo != null && _photoBytes != null) {
        final formData = FormData.fromMap({
          'photo': MultipartFile.fromBytes(
            _photoBytes!,
            filename: _photo!.name,
          ),
        });
        await widget.dio.post(
          '/attendance/cell/${widget.cellId}/meetings/${Uri.encodeComponent(widget.meetingDateIso)}/photo',
          data: formData,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showTopSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao salvar presenças',
      );
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Câmera'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeria'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    // Reduz antes de sair do aparelho. Sem limite de dimensao, a foto de uma
    // camera de 12 MP sai com varios MB, estoura o corpo aceito pelo nginx
    // (413) e ainda gasta banda do lider em campo. 1600px cobre a visualizacao
    // em tela cheia com folga — o thumb da tela usa 180px de altura.
    final picked = await picker.pickImage(
      source: source,
      maxWidth: kMeetingPhotoMaxSide,
      maxHeight: kMeetingPhotoMaxSide,
      imageQuality: kMeetingPhotoQuality,
    );
    if (picked == null) return;
    // XFile.readAsBytes funciona nas duas plataformas; File(path) só em nativo.
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photo = picked;
      _photoBytes = bytes;
    });
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

  String _formatMeetingDate() =>
      formatDateBr(parseMeetingDate(widget.meetingDateIso));

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: DraggableScrollableSheet(
          initialChildSize: 0.85,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          // Column, não SingleChildScrollView na raiz: o cabeçalho e o botão
          // de salvar ficam fixos e só o meio rola.
          builder: (_, controller) => Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pagePaddingH,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PhotoSection(
                        photoBytes: _photoBytes,
                        existingPhotoUrl: _existingPhotoUrl,
                        onPick: _pickPhoto,
                        onRemove: () => setState(() {
                          _photo = null;
                          _photoBytes = null;
                        }),
                      ),
                      const SizedBox(height: AppSpacing.base),
                      // Lição vinda do acervo. Quando a lição não está lá, o
                      // campo de texto abaixo continua valendo.
                      _pickerField(
                        label: 'Lição (material da célula)',
                        icon: Icons.menu_book_outlined,
                        value: _materialTitle,
                        placeholder: _materials.isEmpty
                            ? 'Nenhum material cadastrado'
                            : 'Escolher do acervo',
                        onTap: _materials.isEmpty ? null : _pickMaterial,
                        onClear: _materialId == null
                            ? null
                            : () => setState(() {
                                _materialId = null;
                                _materialTitle = null;
                              }),
                      ),
                      const SizedBox(height: AppSpacing.base),
                      AppTextField(
                        controller: _lessonCtrl,
                        label: _materialId == null
                            ? 'Lição'
                            : 'Observação sobre a lição',
                        hint: 'Tema ministrado no encontro',
                        prefixIcon: Icons.edit_note_outlined,
                        maxLines: 2,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: AppSpacing.base),
                      AppTextField(
                        controller: _ministranteCtrl,
                        label: 'Ministrante',
                        hint: 'Quem ministrou',
                        prefixIcon: Icons.person_outline,
                        textInputAction: TextInputAction.done,
                        suffixIcon: _ministrantes.isEmpty
                            ? null
                            : Icons.groups_2_outlined,
                        onSuffixTap: _ministrantes.isEmpty
                            ? null
                            : _pickMinistrante,
                      ),
                      const SizedBox(height: AppSpacing.base),
                      _buildParticipantsSection(),
                      const SizedBox(height: AppSpacing.base),
                    ],
                  ),
                ),
              ),
              _buildFooter(),
            ],
          ),
        ),
      ),
    );
  }

  /// Campo somente-leitura que abre um seletor. Usado pela lição do acervo.
  Widget _pickerField({
    required String label,
    required IconData icon,
    required String? value,
    required String placeholder,
    required VoidCallback? onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? placeholder,
                style: AppTypography.bodyMedium.copyWith(
                  color: value == null ? AppColors.textSecondary : null,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onClear != null)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Remover material',
                visualDensity: VisualDensity.compact,
              )
            else if (onTap != null)
              const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePaddingH,
        AppSpacing.sm,
        AppSpacing.pagePaddingH,
        AppSpacing.base,
      ),
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
          Text('Registro de presença', style: AppTypography.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Encontro de ${_formatMeetingDate()}',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  /// Lista colapsável. O cabeçalho mostra a contagem, então o líder vê o total
  /// de presentes sem precisar abrir.
  Widget _buildParticipantsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Widget body;
    if (_loading) {
      body = const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_error != null) {
      body = Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
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
              onPressed: _loadInitialData,
            ),
          ],
        ),
      );
    } else if (_participants.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: AppEmptyState(
          title: 'Nenhum participante na célula',
          subtitle: 'Use "Incluir visitante" para adicionar alguém.',
          icon: Icons.people_outline,
        ),
      );
    } else {
      body = Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          children: [
            for (final participant in _participants)
              _ParticipantRow(
                name: (participant['name'] as String?) ?? 'Sem nome',
                isMember: (participant['_type'] as String?) == 'member',
                checked: _presentIds.contains(participant['id'] as String),
                onToggle: () => _toggle(participant['id'] as String),
              ),
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Incluir visitante',
              variant: AppButtonVariant.outline,
              size: AppButtonSize.sm,
              prefixIcon: Icons.person_add_outlined,
              onPressed: _showAddVisitorSheet,
            ),
          ],
        ),
      );
    }

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () =>
                setState(() => _participantsExpanded = !_participantsExpanded),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: AppSpacing.iconSm,
                    color: isDark ? AppColors.linkDark : AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Participantes',
                      style: AppTypography.titleSmall,
                    ),
                  ),
                  Text(
                    _presenceLabel,
                    style: AppTypography.labelMedium.copyWith(
                      color: isDark
                          ? AppColors.text3Dark
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    _participantsExpanded
                        ? Icons.expand_less
                        : Icons.expand_more,
                    color: isDark
                        ? AppColors.text3Dark
                        : AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (_participantsExpanded) ...[
            Divider(
              height: 1,
              color: isDark ? AppColors.borderSoftDark : AppColors.borderSoft,
            ),
            body,
          ],
        ],
      ),
    );
  }

  String get _presenceLabel {
    if (_loading || _error != null) return '';
    return '${_presentIds.length} de ${_participants.length}';
  }

  void _toggle(String participantId) {
    setState(() {
      if (_presentIds.contains(participantId)) {
        _presentIds.remove(participantId);
      } else {
        _presentIds.add(participantId);
      }
    });
  }

  /// Rodapé fixo: o botão de salvar fica sempre visível, sem depender de
  /// rolar a lista de participantes até o fim.
  Widget _buildFooter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.divider,
          ),
        ),
      ),
      child: AppButton(
        label: _loading
            ? 'Carregando...'
            : 'Salvar presença (${_presentIds.length})',
        prefixIcon: Icons.check_circle_outline,
        isLoading: _saving,
        onPressed: (_loading || _saving || _error != null) ? null : _save,
      ),
    );
  }
}

/// Linha de participante com badge de tipo bem visível e a marcação de presença.
class _ParticipantRow extends StatelessWidget {
  const _ParticipantRow({
    required this.name,
    required this.isMember,
    required this.checked,
    required this.onToggle,
  });

  final String name;
  final bool isMember;
  final bool checked;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Checkbox(
              value: checked,
              onChanged: (_) => onToggle(),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                name,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: checked ? FontWeight.w600 : FontWeight.w400,
                  color: isDark ? AppColors.textDark : AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppBadge(
              label: isMember ? 'Membro' : 'Visitante',
              variant: isMember
                  ? AppBadgeVariant.success
                  : AppBadgeVariant.info,
              size: AppBadgeSize.sm,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// TAB 3: MATERIALS
// ═══════════════════════════════════════════════════════════════════════════

class _MaterialsTab extends StatefulWidget {
  const _MaterialsTab({required this.cellId});

  final String cellId;

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
    _dio = getIt<DioClient>().dio;
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
      final resp = await _dio.get(
        '/materials',
        queryParameters: {'cellId': widget.cellId},
      );
      final data =
          (resp.data as Map<String, dynamic>)['materials'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _materials = data
            .map((e) => _MaterialData.fromJson(e as Map<String, dynamic>))
            .toList();
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
      _showTopSnackBar(context, 'Erro ao abrir o arquivo');
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
  const _SpiritualHistoryTab({required this.cellId});

  final String cellId;

  @override
  State<_SpiritualHistoryTab> createState() => _SpiritualHistoryTabState();
}

class _SpiritualHistoryTabState extends State<_SpiritualHistoryTab> {
  late final Dio _dio;
  bool _loading = true;
  String? _error;
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
    _dio = getIt<DioClient>().dio;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final histResp = await _dio.get(
        '/spiritual-history/cell/${widget.cellId}',
      );
      final history =
          ((histResp.data as Map<String, dynamic>)['history'] as List)
              .cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
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
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddHistoryEventSheet(dio: _dio, cellId: widget.cellId),
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
  String? _selectedPersonId;
  String _selectedType = 'enviado_batismo';
  bool _loadingPeople = true;
  bool _saving = false;

  /// Membros e visitantes da célula na mesma lista — quem já é membro também
  /// é enviado para batismo.
  List<CellAttendee> _people = [];

  static const _types = [
    ('enviado_batismo', 'Enviado para Batismo'),
    ('batizado', 'Batizado'),
    ('enviado_treinamento_lider', 'Enviado p/ Treinamento de Líder'),
    ('concluiu_treinamento', 'Concluiu Treinamento'),
    ('tornou_se_lider', 'Tornou-se Líder'),
  ];

  /// Eventos de batismo só fazem sentido para quem ainda não é batizado —
  /// listar o resto só atrapalha a busca do líder.
  bool get _onlyUnbaptized =>
      _selectedType == 'enviado_batismo' || _selectedType == 'batizado';

  List<CellAttendee> get _visiblePeople => _onlyUnbaptized
      ? _people.where((p) => p.isBaptized != true).toList()
      : _people;

  @override
  void initState() {
    super.initState();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    try {
      final resp = await widget.dio.get(
        '/attendance/cell/${widget.cellId}/attendees',
      );
      final raw =
          ((resp.data as Map<String, dynamic>)['attendees'] as List? ?? [])
              .cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _people = raw.map(CellAttendee.fromJson).toList();
        _loadingPeople = false;
        _syncSelection();
      });
    } catch (e) {
      debugPrint('[AddHistorySheet] Erro ao carregar pessoas: $e');
      if (!mounted) return;
      setState(() => _loadingPeople = false);
    }
  }

  /// Mantém a seleção válida quando a lista muda de tamanho ao trocar o tipo
  /// de evento — um id fora dos itens quebra o DropdownButton.
  void _syncSelection() {
    final visible = _visiblePeople;
    if (visible.any((p) => p.id == _selectedPersonId)) return;
    _selectedPersonId = visible.isEmpty ? null : visible.first.id;
  }

  /// Rótulo do badge: função na célula para membros, "Visitante" no resto.
  static String _personRoleLabel(CellAttendee person) => switch (person.roleInCell) {
    'VICE_LIDER' => 'Vice-líder',
    'ANFITRIAO' => 'Anfitrião',
    'MEMBRO' => 'Membro',
    _ => 'Visitante',
  };

  Future<void> _save() async {
    final personId = _selectedPersonId;
    if (personId == null) return;
    final person = _visiblePeople.firstWhere((p) => p.id == personId);
    setState(() => _saving = true);
    try {
      await widget.dio.post(
        '/spiritual-history',
        data: {
          if (person.isMember) 'memberId': personId else 'visitorId': personId,
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
      _showTopSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao registrar evento',
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

              // Pessoa: membros e visitantes na mesma lista.
              Text(
                'Pessoa',
                style: AppTypography.labelMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              if (_loadingPeople)
                const LinearProgressIndicator()
              else if (_visiblePeople.isEmpty)
                Text(
                  _onlyUnbaptized
                      ? 'Todos da célula já estão batizados'
                      : 'Ninguém na célula ainda',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedPersonId,
                  isExpanded: true,
                  items: _visiblePeople
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              AppBadge(
                                label: _personRoleLabel(p),
                                variant: p.isMember
                                    ? AppBadgeVariant.success
                                    : AppBadgeVariant.info,
                                size: AppBadgeSize.sm,
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedPersonId = v),
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
                initialValue: _selectedType,
                items: _types
                    .map(
                      (t) => DropdownMenuItem(value: t.$1, child: Text(t.$2)),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  _selectedType = v!;
                  _syncSelection();
                }),
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
                    (_saving || _loadingPeople || _selectedPersonId == null)
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
