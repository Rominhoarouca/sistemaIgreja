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
  bool _showAll = true;
  bool _loading = true;
  String? _error;
  List<_VisitorData> _allVisitors = [];

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
      _loading = true;
      _error = null;
    });

    try {
      final resp = await _dio.get('/visitors');
      final data = (resp.data as Map<String, dynamic>)['data'] as List;
      if (!mounted) return;
      setState(() {
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

  List<_VisitorData> get _filtered {
    final q = _query.toLowerCase();
    final list = _allVisitors.where((v) {
      if (q.isEmpty) return true;
      return v.name.toLowerCase().contains(q) ||
          v.phone.contains(q) ||
          v.neighborhood.toLowerCase().contains(q);
    }).toList();
    return _showAll ? list : list.take(5).toList();
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
              onPressed: _loadVisitors,
            ),
          ],
        ),
      );
    }

    final filtered = _filtered;

    return CustomScrollView(
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
              AppSectionHeader(
                title: 'Visitantes Encaminhados',
                actionLabel: _showAll ? 'Mostrar menos' : 'Ver todos',
                onAction: () => setState(() => _showAll = !_showAll),
              ),
              const SizedBox(height: AppSpacing.sm),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePaddingH,
          ),
          sliver: filtered.isEmpty
              ? SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xl),
                    child: Center(
                      child: Text(
                        'Nenhum visitante encontrado',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                )
              : SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) => _VisitorListTile(
                    visitor: filtered[i],
                    onOpenDetails: () => _openVisitorDetails(filtered[i]),
                  ),
                ),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.xl)),
      ],
    );
  }

  Future<void> _openVisitorDetails(_VisitorData visitor) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _VisitorDetailSheet(visitor: visitor, dio: _dio),
    );

    if (changed == true) {
      _loadVisitors();
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
  const _VisitorListTile({required this.visitor, required this.onOpenDetails});

  final _VisitorData visitor;
  final VoidCallback onOpenDetails;

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

class _VisitorDetailSheet extends StatefulWidget {
  const _VisitorDetailSheet({required this.visitor, required this.dio});

  final _VisitorData visitor;
  final Dio dio;

  @override
  State<_VisitorDetailSheet> createState() => _VisitorDetailSheetState();
}

class _VisitorDetailSheetState extends State<_VisitorDetailSheet> {
  late String _status;
  bool _updatingStatus = false;
  bool _converting = false;

  @override
  void initState() {
    super.initState();
    _status = widget.visitor.status;
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
// TAB 2: ATTENDANCE
// ═══════════════════════════════════════════════════════════════════════════

class _AttendanceTab extends StatefulWidget {
  const _AttendanceTab();

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  final List<_MeetingData> _meetings = [
    _MeetingData(
      date: DateTime.now(),
      attendees: ['Maria Fernandes', 'Paulo Santos', 'Ana Lima'],
      total: 5,
    ),
    _MeetingData(
      date: DateTime.now().subtract(const Duration(days: 7)),
      attendees: [
        'Maria Fernandes',
        'Carlos Souza',
        'Beatriz Costa',
        'Rodrigo Alves',
      ],
      total: 5,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
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
              ..._meetings.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _AttendanceMeetingCard(
                    meeting: m,
                    onRegister: () => _showRegisterSheet(context, m),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ]),
          ),
        ),
      ],
    );
  }

  void _showNewMeetingSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _NewMeetingSheet(
        onConfirm: (date) {
          setState(() {
            _meetings.insert(
              0,
              _MeetingData(date: date, attendees: [], total: 5),
            );
          });
        },
      ),
    );
  }

  void _showRegisterSheet(BuildContext context, _MeetingData meeting) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _RegisterAttendanceSheet(
        meeting: meeting,
        onSave: (attendees) {
          setState(() => meeting.attendees = attendees);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Presença registrada: ${attendees.length} membros'),
              backgroundColor: AppColors.success,
            ),
          );
        },
      ),
    );
  }
}

class _MeetingData {
  final DateTime date;
  List<String> attendees;
  final int total;

  _MeetingData({
    required this.date,
    required this.attendees,
    required this.total,
  });
}

class _AttendanceMeetingCard extends StatelessWidget {
  const _AttendanceMeetingCard({
    required this.meeting,
    required this.onRegister,
  });

  final _MeetingData meeting;
  final VoidCallback onRegister;

  @override
  Widget build(BuildContext context) {
    final d = meeting.date;
    final label =
        'Encontro de ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
    final present = meeting.attendees.length;
    final pct = meeting.total > 0 ? (present / meeting.total * 100).round() : 0;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
              AppButton(
                label: 'Registrar',
                size: AppButtonSize.sm,
                isFullWidth: false,
                variant: AppButtonVariant.secondary,
                onPressed: onRegister,
              ),
            ],
          ),
          if (present > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const SizedBox(width: 36),
                Text(
                  '$present de ${meeting.total} presentes ($pct%)',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _NewMeetingSheet extends StatefulWidget {
  const _NewMeetingSheet({required this.onConfirm});

  final void Function(DateTime) onConfirm;

  @override
  State<_NewMeetingSheet> createState() => _NewMeetingSheetState();
}

class _NewMeetingSheetState extends State<_NewMeetingSheet> {
  DateTime _selectedDate = DateTime.now();

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
              onPressed: () {
                Navigator.of(context).pop();
                widget.onConfirm(_selectedDate);
              },
            ),
            const SizedBox(height: AppSpacing.base),
          ],
        ),
      ),
    );
  }
}

class _RegisterAttendanceSheet extends StatefulWidget {
  const _RegisterAttendanceSheet({required this.meeting, required this.onSave});

  final _MeetingData meeting;
  final void Function(List<String>) onSave;

  @override
  State<_RegisterAttendanceSheet> createState() =>
      _RegisterAttendanceSheetState();
}

class _RegisterAttendanceSheetState extends State<_RegisterAttendanceSheet> {
  static const _members = [
    'Maria Fernandes',
    'Paulo Santos',
    'Ana Lima',
    'Carlos Souza',
    'Beatriz Costa',
  ];

  late Set<String> _present;

  @override
  void initState() {
    super.initState();
    _present = Set.from(widget.meeting.attendees);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.meeting.date;
    final label =
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePaddingH,
              vertical: AppSpacing.base,
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
                Text('Registrar Presença', style: AppTypography.headlineSmall),
                Text(
                  'Encontro de $label',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: controller,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePaddingH,
              ),
              itemCount: _members.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final member = _members[i];
                final present = _present.contains(member);
                return CheckboxListTile(
                  value: present,
                  onChanged: (v) => setState(() {
                    if (v!) {
                      _present.add(member);
                    } else {
                      _present.remove(member);
                    }
                  }),
                  title: Text(member, style: AppTypography.titleSmall),
                  secondary: AppAvatar(
                    initials: member.split(' ').map((e) => e[0]).take(2).join(),
                    size: 36,
                  ),
                  activeColor: AppColors.primary,
                );
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pagePaddingH,
              AppSpacing.base,
              AppSpacing.pagePaddingH,
              AppSpacing.pagePaddingH + MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: AppButton(
              label: 'Salvar presença (${_present.length}/${_members.length})',
              prefixIcon: Icons.save_outlined,
              onPressed: () {
                Navigator.of(context).pop();
                widget.onSave(_present.toList());
              },
            ),
          ),
        ],
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
      final resp = await _dio.get('/materials');
      final data = (resp.data as Map<String, dynamic>)['materials'] as List;
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
  final List<_HistoryEvent> _events = [
    _HistoryEvent(
      visitor: 'Maria Fernandes',
      type: 'enviado_batismo',
      date: DateTime.now().subtract(const Duration(days: 10)),
      description: 'Encaminhada para batismo em água.',
    ),
    _HistoryEvent(
      visitor: 'Paulo Santos',
      type: 'enviado_treinamento_lider',
      date: DateTime.now().subtract(const Duration(days: 30)),
      description: 'Em treinamento de líderes.',
    ),
    _HistoryEvent(
      visitor: 'Ana Lima',
      type: 'concluiu_treinamento',
      date: DateTime.now().subtract(const Duration(days: 5)),
      description: '',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
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
              onTap: () => _showDetail(context, e),
            ),
          ),
      ],
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddHistoryEventSheet(
        onAdd: (event) => setState(() => _events.insert(0, event)),
      ),
    );
  }

  void _showDetail(BuildContext context, _HistoryEvent event) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _HistoryDetailSheet(event: event),
    );
  }
}

class _HistoryEvent {
  final String visitor;
  final String type;
  final DateTime date;
  final String description;

  const _HistoryEvent({
    required this.visitor,
    required this.type,
    required this.date,
    required this.description,
  });
}

class _HistoryEventCard extends StatelessWidget {
  const _HistoryEventCard({required this.event, required this.onTap});

  final _HistoryEvent event;
  final VoidCallback onTap;

  static const _typeInfo = {
    'enviado_batismo': (
      Icons.water_outlined,
      AppColors.primary,
      'Enviado p/ Batismo',
    ),
    'batizado': (Icons.water_drop_outlined, AppColors.info, 'Batizado'),
    'enviado_treinamento_lider': (
      Icons.school_outlined,
      AppColors.accent,
      'Em Treinamento Líder',
    ),
    'concluiu_treinamento': (
      Icons.workspace_premium_outlined,
      AppColors.success,
      'Concluiu Treinamento',
    ),
    'tornou_se_lider': (
      Icons.star_outline,
      AppColors.warning,
      'Tornou-se Líder',
    ),
  };

  @override
  Widget build(BuildContext context) {
    final info =
        _typeInfo[event.type] ??
        (Icons.history_outlined, AppColors.grey500, event.type);

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: info.$2.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            ),
            child: Icon(info.$1, color: info.$2, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info.$3, style: AppTypography.titleSmall),
                Text(
                  event.visitor,
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
                '${event.date.day.toString().padLeft(2, '0')}/${event.date.month.toString().padLeft(2, '0')}',
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
  const _HistoryDetailSheet({required this.event});

  final _HistoryEvent event;

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
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(
                    Icons.person_outline,
                    color: AppColors.primary,
                  ),
                  title: const Text('Visitante'),
                  subtitle: Text(event.visitor),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.category_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Tipo de evento'),
                  subtitle: Text(event.type.replaceAll('_', ' ')),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(
                    Icons.calendar_today_outlined,
                    color: AppColors.primary,
                  ),
                  title: const Text('Data'),
                  subtitle: Text(
                    '${event.date.day.toString().padLeft(2, '0')}/${event.date.month.toString().padLeft(2, '0')}/${event.date.year}',
                  ),
                ),
                if (event.description.isNotEmpty) ...[
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.notes_outlined,
                      color: AppColors.primary,
                    ),
                    title: const Text('Descrição'),
                    subtitle: Text(event.description),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl2),
        ],
      ),
    );
  }
}

class _AddHistoryEventSheet extends StatefulWidget {
  const _AddHistoryEventSheet({required this.onAdd});

  final void Function(_HistoryEvent) onAdd;

  @override
  State<_AddHistoryEventSheet> createState() => _AddHistoryEventSheetState();
}

class _AddHistoryEventSheetState extends State<_AddHistoryEventSheet> {
  final _descCtrl = TextEditingController();
  String _selectedVisitor = 'Maria Fernandes';
  String _selectedType = 'enviado_batismo';
  DateTime _date = DateTime.now();

  static const _visitors = [
    'Maria Fernandes',
    'Paulo Santos',
    'Ana Lima',
    'Carlos Souza',
    'Beatriz Costa',
  ];

  static const _types = [
    ('enviado_batismo', 'Enviado para Batismo'),
    ('batizado', 'Batizado'),
    ('enviado_treinamento_lider', 'Enviado p/ Treinamento de Líder'),
    ('concluiu_treinamento', 'Concluiu Treinamento'),
    ('tornou_se_lider', 'Tornou-se Líder'),
  ];

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
              DropdownButtonFormField<String>(
                value: _selectedVisitor,
                items: _visitors
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedVisitor = v!),
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
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.onAdd(
                    _HistoryEvent(
                      visitor: _selectedVisitor,
                      type: _selectedType,
                      date: _date,
                      description: _descCtrl.text,
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.base),
            ],
          ),
        ),
      ),
    );
  }
}
