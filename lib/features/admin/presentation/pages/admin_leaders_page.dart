import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/auth_storage.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data Models
// ─────────────────────────────────────────────────────────────────────────────

class _LeaderInfo {
  _LeaderInfo({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.address,
    this.description,
    this.createdAt,
    this.supervisorId,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String? address;
  String? description;
  final DateTime? createdAt;
  final String? supervisorId;
  String? coordenacaoName;
  String? coordenacaoColor;
  final List<_CellInfo> cells = [];

  factory _LeaderInfo.fromJson(Map<String, dynamic> json) => _LeaderInfo(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
    phone: json['phone'] as String? ?? '',
    address: json['address'] as String?,
    description: json['description'] as String?,
    supervisorId: json['supervisorId'] as String?,
    createdAt: json['createdAt'] != null
        ? DateTime.tryParse(json['createdAt'] as String)
        : null,
  );

  String get initials => name
      .split(' ')
      .where((e) => e.isNotEmpty)
      .map((e) => e[0])
      .take(2)
      .join();
}

class _CellInfo {
  _CellInfo({
    required this.id,
    required this.name,
    required this.leaderId,
    required this.neighborhood,
    required this.city,
    required this.dayOfWeek,
    required this.time,
    required this.memberCount,
  });

  final String id;
  final String name;
  final String leaderId;
  final String neighborhood;
  final String city;
  final String dayOfWeek;
  final String time;
  final int memberCount;

  factory _CellInfo.fromJson(Map<String, dynamic> json) => _CellInfo(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    leaderId: json['leaderId'] as String? ?? '',
    neighborhood: json['neighborhood'] as String? ?? '',
    city: json['city'] as String? ?? '',
    dayOfWeek: json['dayOfWeek'] as String? ?? '',
    time: json['time'] as String? ?? '',
    memberCount: json['currentCount'] as int? ?? 0,
  );
}

class _MeetingInfo {
  _MeetingInfo({
    required this.date,
    required this.total,
    required this.present,
  });

  final DateTime date;
  final int total;
  final int present;

  double get rate => total > 0 ? present / total * 100 : 0;
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Page
// ─────────────────────────────────────────────────────────────────────────────

/// Admin page for viewing all leaders, their cells and attendance frequency.
class AdminLeadersPage extends StatefulWidget {
  const AdminLeadersPage({super.key});

  @override
  State<AdminLeadersPage> createState() => _AdminLeadersPageState();
}

class _AdminLeadersPageState extends State<AdminLeadersPage> {
  late final Dio _dio;
  bool _loading = true;
  String? _error;
  List<_LeaderInfo> _leaders = [];
  final _searchCtrl = TextEditingController();
  String _query = '';

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
        _dio.get('/users/leaders'),
        _dio.get('/cells'),
        _dio.get('/users/supervisors'),
        _dio.get('/coordenacoes'),
      ]);

      final leaderList =
          ((results[0].data as Map<String, dynamic>)['leaders'] as List)
              .cast<Map<String, dynamic>>();
      final cellList =
          ((results[1].data as Map<String, dynamic>)['cells'] as List)
              .cast<Map<String, dynamic>>();
      final supervisorList =
          ((results[2].data as Map<String, dynamic>)['supervisors'] as List)
              .cast<Map<String, dynamic>>();
      final coordenacaoList =
          ((results[3].data as Map<String, dynamic>)['coordenacoes'] as List)
              .cast<Map<String, dynamic>>();

      // Build supervisor → coordenacao lookup
      final supervisorCoordenacao = <String, Map<String, dynamic>>{};
      for (final sup in supervisorList) {
        final coordId = sup['coordenacaoId'] as String?;
        if (coordId != null) {
          final coord = coordenacaoList.firstWhere(
            (c) => c['id'] == coordId,
            orElse: () => <String, dynamic>{},
          );
          if (coord.isNotEmpty) {
            supervisorCoordenacao[sup['id'] as String] = coord;
          }
        }
      }

      // Group cells by leaderId (client-side)
      final cellsByLeader = <String, List<_CellInfo>>{};
      for (final c in cellList) {
        final leaderId = c['leaderId'] as String? ?? '';
        cellsByLeader
            .putIfAbsent(leaderId, () => [])
            .add(_CellInfo.fromJson(c));
      }

      final leaders = leaderList.map((l) {
        final info = _LeaderInfo.fromJson(l);
        info.cells.addAll(cellsByLeader[info.id] ?? []);
        // Enrich with coordenacao color via supervisor
        if (info.supervisorId != null) {
          final coord = supervisorCoordenacao[info.supervisorId];
          if (coord != null) {
            info.coordenacaoName = coord['name'] as String?;
            info.coordenacaoColor = coord['color'] as String?;
          }
        }
        return info;
      }).toList();

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

  List<_LeaderInfo> get _filtered {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _leaders;
    return _leaders
        .where(
          (l) =>
              l.name.toLowerCase().contains(q) ||
              l.email.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        title: const Text('Líderes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loading ? null : _loadData,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(error: _error!, onRetry: _loadData)
          : _buildList(),
    );
  }

  Widget _buildList() {
    final filtered = _filtered;
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        children: [
          AppSearchField(
            hint: 'Pesquisar líder por nome ou e-mail...',
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${filtered.length} líder${filtered.length != 1 ? 'es' : ''}',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (filtered.isEmpty)
            AppEmptyState(
              title: 'Nenhum líder encontrado',
              subtitle: 'Cadastre líderes no painel de administração.',
              icon: Icons.person_outline,
            )
          else
            ...filtered.map(
              (l) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _LeaderCard(leader: l, onTap: () => _openDetail(l)),
              ),
            ),
        ],
      ),
    );
  }

  void _openDetail(_LeaderInfo leader) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            _LeaderDetailPage(leader: leader, dio: _dio, onUpdated: _loadData),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

Color _parseColor(String? hex) {
  if (hex == null) return AppColors.textSecondary;
  try {
    return Color(int.parse(hex.replaceFirst('#', '0xFF')));
  } catch (_) {
    return AppColors.textSecondary;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Leader Card
// ─────────────────────────────────────────────────────────────────────────────

class _LeaderCard extends StatelessWidget {
  const _LeaderCard({required this.leader, required this.onTap});

  final _LeaderInfo leader;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppAvatar(initials: leader.initials),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(leader.name, style: AppTypography.titleSmall),
                if (leader.email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    leader.email,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (leader.phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    leader.phone,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
                if (leader.description != null &&
                    leader.description!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    leader.description!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (leader.coordenacaoName != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: BoxDecoration(
                          color: _parseColor(leader.coordenacaoColor),
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        leader.coordenacaoName!,
                        style: AppTypography.labelSmall.copyWith(
                          color: _parseColor(leader.coordenacaoColor),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.home_outlined,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${leader.cells.length}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'célula${leader.cells.length != 1 ? 's' : ''}',
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              const Icon(
                Icons.chevron_right,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Leader Detail Page (pushed via Navigator)
// ─────────────────────────────────────────────────────────────────────────────

class _LeaderDetailPage extends StatefulWidget {
  const _LeaderDetailPage({
    required this.leader,
    required this.dio,
    required this.onUpdated,
  });

  final _LeaderInfo leader;
  final Dio dio;
  final VoidCallback onUpdated;

  @override
  State<_LeaderDetailPage> createState() => _LeaderDetailPageState();
}

class _LeaderDetailPageState extends State<_LeaderDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  late _LeaderInfo _leader;

  @override
  void initState() {
    super.initState();
    _leader = widget.leader;
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        title: Text(_leader.name),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.white,
          labelColor: AppColors.white,
          unselectedLabelColor: AppColors.white.withValues(alpha: 0.65),
          tabs: const [
            Tab(icon: Icon(Icons.person_outline), text: 'Dados'),
            Tab(icon: Icon(Icons.home_outlined), text: 'Células'),
            Tab(icon: Icon(Icons.people_outline), text: 'Visitantes'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _LeaderDataTab(
            leader: _leader,
            dio: widget.dio,
            onDescriptionUpdated: (desc) {
              setState(() => _leader.description = desc);
              widget.onUpdated();
            },
          ),
          _LeaderCellsTab(leader: _leader, dio: widget.dio),
          _LeaderVisitorsTab(leaderId: _leader.id, dio: widget.dio),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Dados
// ─────────────────────────────────────────────────────────────────────────────

class _LeaderDataTab extends StatelessWidget {
  const _LeaderDataTab({
    required this.leader,
    required this.dio,
    required this.onDescriptionUpdated,
  });

  final _LeaderInfo leader;
  final Dio dio;
  final void Function(String?) onDescriptionUpdated;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
      children: [
        // Avatar header
        Center(
          child: Column(
            children: [
              AppAvatar(initials: leader.initials, size: 64),
              const SizedBox(height: AppSpacing.sm),
              Text(leader.name, style: AppTypography.headlineSmall),
              if (leader.email.isNotEmpty)
                Text(
                  leader.email,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Info card
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _InfoRow(
                icon: Icons.badge_outlined,
                label: 'Cargo',
                value: 'Líder',
              ),
              if (leader.phone.isNotEmpty) ...[
                const Divider(height: 1),
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Telefone',
                  value: leader.phone,
                ),
              ],
              if (leader.address != null && leader.address!.isNotEmpty) ...[
                const Divider(height: 1),
                _InfoRow(
                  icon: Icons.location_on_outlined,
                  label: 'Endereço',
                  value: leader.address!,
                ),
              ],
              if (leader.createdAt != null) ...[
                const Divider(height: 1),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Cadastrado em',
                  value: fmt.format(leader.createdAt!),
                ),
              ],
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.home_outlined,
                label: 'Células',
                value:
                    '${leader.cells.length} célula${leader.cells.length != 1 ? 's' : ''}',
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.base),

        // Description section
        Row(
          children: [
            Text('Descrição', style: AppTypography.titleMedium),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Editar'),
              onPressed: () => _editDescription(context),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        AppCard(
          child: leader.description != null && leader.description!.isNotEmpty
              ? Text(leader.description!, style: AppTypography.bodyMedium)
              : Text(
                  'Nenhuma descrição adicionada.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Promote section
        Text('Cargo', style: AppTypography.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        AppCard(
          child: Row(
            children: [
              const Icon(
                Icons.badge_outlined,
                color: AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Líder', style: AppTypography.bodyMedium),
                    Text(
                      'Promova para Supervisor se desejar.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                icon: const Icon(Icons.arrow_upward, size: 16),
                label: const Text('Promover'),
                onPressed: () => _confirmPromote(context),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl2),
      ],
    );
  }

  void _confirmPromote(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Promover para Supervisor'),
        content: Text(
          'Deseja promover ${leader.name} a Supervisor? '
          'Ele passará a ter acesso ao painel de supervisor.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await dio.patch(
                  '/users/leaders/${leader.id}/promote',
                  data: {'targetRole': 'SUPERVISOR'},
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Líder promovido a Supervisor com sucesso!'),
                    backgroundColor: AppColors.success,
                  ),
                );
                onDescriptionUpdated(leader.description);
              } on DioException catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      e.response?.data?['error']?['message'] as String? ??
                          'Erro ao promover líder',
                    ),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: const Text('Promover'),
          ),
        ],
      ),
    );
  }

  void _editDescription(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditDescriptionSheet(
        leader: leader,
        dio: dio,
        onSaved: onDescriptionUpdated,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Description Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EditDescriptionSheet extends StatefulWidget {
  const _EditDescriptionSheet({
    required this.leader,
    required this.dio,
    required this.onSaved,
  });

  final _LeaderInfo leader;
  final Dio dio;
  final void Function(String?) onSaved;

  @override
  State<_EditDescriptionSheet> createState() => _EditDescriptionSheetState();
}

class _EditDescriptionSheetState extends State<_EditDescriptionSheet> {
  late final TextEditingController _ctrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.leader.description ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final description = _ctrl.text.trim().isEmpty ? null : _ctrl.text.trim();
      await widget.dio.patch(
        '/users/leaders/${widget.leader.id}',
        data: {'description': description},
      );
      if (!mounted) return;
      widget.onSaved(description);
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?['message'] as String? ??
                'Erro ao salvar descrição',
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
        AppSpacing.base,
        AppSpacing.pagePaddingH,
        AppSpacing.base + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Text('Descrição do Líder', style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.leader.name,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          AppTextField(
            controller: _ctrl,
            label: 'Descrição',
            hint: 'Descreva o líder, suas responsabilidades, região...',
            maxLines: 4,
          ),
          const SizedBox(height: AppSpacing.base),
          AppButton(
            label: 'Salvar Descrição',
            isLoading: _saving,
            onPressed: _save,
            prefixIcon: Icons.save_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Células
// ─────────────────────────────────────────────────────────────────────────────

class _LeaderCellsTab extends StatefulWidget {
  const _LeaderCellsTab({required this.leader, required this.dio});

  final _LeaderInfo leader;
  final Dio dio;

  @override
  State<_LeaderCellsTab> createState() => _LeaderCellsTabState();
}

class _LeaderCellsTabState extends State<_LeaderCellsTab> {
  final _meetingsByCell = <String, List<_MeetingInfo>>{};
  final _loadingCells = <String>{};

  @override
  void initState() {
    super.initState();
    for (final cell in widget.leader.cells) {
      _loadMeetings(cell.id);
    }
  }

  Future<void> _loadMeetings(String cellId) async {
    if (_loadingCells.contains(cellId)) return;
    setState(() => _loadingCells.add(cellId));
    try {
      final resp = await widget.dio.get('/attendance/cell/$cellId/meetings');
      final list =
          ((resp.data as Map<String, dynamic>)['meetings'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      if (!mounted) return;
      setState(() {
        _meetingsByCell[cellId] = list
            .map(
              (m) => _MeetingInfo(
                date: DateTime.parse(m['meetingDate'] as String),
                total: m['total'] as int? ?? 0,
                present: m['present'] as int? ?? 0,
              ),
            )
            .toList();
        _loadingCells.remove(cellId);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _meetingsByCell[cellId] = [];
        _loadingCells.remove(cellId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.leader.cells.isEmpty) {
      return const AppEmptyState(
        title: 'Nenhuma célula',
        subtitle: 'Este líder ainda não possui células cadastradas.',
        icon: Icons.home_outlined,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
      itemCount: widget.leader.cells.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (ctx, i) {
        final cell = widget.leader.cells[i];
        final meetings = _meetingsByCell[cell.id];
        final loading = _loadingCells.contains(cell.id);

        double avgRate = 0;
        int meetingCount = 0;
        if (meetings != null && meetings.isNotEmpty) {
          meetingCount = meetings.length;
          final withData = meetings.where((m) => m.total > 0).toList();
          if (withData.isNotEmpty) {
            avgRate =
                withData.map((m) => m.rate).reduce((a, b) => a + b) /
                withData.length;
          }
        }

        return _CellAttendanceCard(
          cell: cell,
          avgRate: avgRate,
          meetingCount: meetingCount,
          loading: loading,
          onTap: meetings != null && meetings.isNotEmpty
              ? () => _showMeetingsSheet(ctx, cell, meetings)
              : null,
        );
      },
    );
  }

  void _showMeetingsSheet(
    BuildContext ctx,
    _CellInfo cell,
    List<_MeetingInfo> meetings,
  ) {
    showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CellMeetingsSheet(cell: cell, meetings: meetings),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cell Attendance Card
// ─────────────────────────────────────────────────────────────────────────────

class _CellAttendanceCard extends StatelessWidget {
  const _CellAttendanceCard({
    required this.cell,
    required this.avgRate,
    required this.meetingCount,
    required this.loading,
    this.onTap,
  });

  final _CellInfo cell;
  final double avgRate;
  final int meetingCount;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(cell.name, style: AppTypography.titleSmall)),
              if (loading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (meetingCount > 0)
                _AttendanceBadge(rate: avgRate),
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
                  '${cell.neighborhood}, ${cell.city}',
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
                '${_dayLabel(cell.dayOfWeek)} às ${cell.time}',
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
                '${cell.memberCount} membro${cell.memberCount != 1 ? 's' : ''}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (!loading) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(
                  Icons.event_outlined,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '$meetingCount encontro${meetingCount != 1 ? 's' : ''}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (onTap != null) ...[
                  const Spacer(),
                  Text(
                    'Ver histórico',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _dayLabel(String day) => switch (day) {
    'segunda' => 'Segunda',
    'terca' => 'Terça',
    'quarta' => 'Quarta',
    'quinta' => 'Quinta',
    'sexta' => 'Sexta',
    'sabado' => 'Sábado',
    'domingo' => 'Domingo',
    _ => day,
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// Cell Meetings History Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CellMeetingsSheet extends StatelessWidget {
  const _CellMeetingsSheet({required this.cell, required this.meetings});

  final _CellInfo cell;
  final List<_MeetingInfo> meetings;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');

    // Overall stats
    final withData = meetings.where((m) => m.total > 0).toList();
    final overallRate = withData.isEmpty
        ? 0.0
        : withData.map((m) => m.rate).reduce((a, b) => a + b) / withData.length;
    final totalPresences = meetings.fold<int>(0, (sum, m) => sum + m.present);
    final totalSlots = meetings.fold<int>(0, (sum, m) => sum + m.total);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, ctrl) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
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
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
                Text(
                  'Histórico de Frequência',
                  style: AppTypography.titleMedium,
                ),
                Text(
                  cell.name,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.base),

                // Summary row
                Row(
                  children: [
                    Expanded(
                      child: _StatMini(
                        label: 'Encontros',
                        value: '${meetings.length}',
                        icon: Icons.event_outlined,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _StatMini(
                        label: 'Presenças totais',
                        value: '$totalPresences / $totalSlots',
                        icon: Icons.check_circle_outline,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _StatMini(
                        label: 'Frequência média',
                        value: '${overallRate.toStringAsFixed(0)}%',
                        icon: Icons.bar_chart_outlined,
                        valueColor: _rateColor(overallRate),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.base),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              controller: ctrl,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePaddingH,
              ),
              itemCount: meetings.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.xs),
              itemBuilder: (_, i) {
                final m = meetings[i];
                final color = _rateColor(m.rate);
                return AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.event_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fmt.format(m.date),
                              style: AppTypography.bodyMedium,
                            ),
                            Text(
                              '${m.present} presente${m.present != 1 ? 's' : ''}'
                              ' de ${m.total} registrado${m.total != 1 ? 's' : ''}',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          m.total > 0 ? '${m.rate.toStringAsFixed(0)}%' : '—',
                          style: AppTypography.labelSmall.copyWith(
                            color: color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Color _rateColor(double rate) {
    if (rate >= 75) return AppColors.success;
    if (rate >= 50) return AppColors.warning;
    return AppColors.error;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Visitantes
// ─────────────────────────────────────────────────────────────────────────────

class _LeaderVisitorsTab extends StatefulWidget {
  const _LeaderVisitorsTab({required this.leaderId, required this.dio});

  final String leaderId;
  final Dio dio;

  @override
  State<_LeaderVisitorsTab> createState() => _LeaderVisitorsTabState();
}

class _LeaderVisitorsTabState extends State<_LeaderVisitorsTab> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _visitors = [];

  @override
  void initState() {
    super.initState();
    _loadVisitors();
  }

  Future<void> _loadVisitors() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await widget.dio.get(
        '/visitors',
        queryParameters: {'leaderId': widget.leaderId, 'pageSize': 100},
      );
      final list =
          ((resp.data as Map<String, dynamic>)['visitors'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      if (!mounted) return;
      setState(() {
        _visitors = list;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _ErrorView(error: _error!, onRetry: _loadVisitors);
    }
    if (_visitors.isEmpty) {
      return const AppEmptyState(
        title: 'Nenhum visitante',
        subtitle: 'Este líder ainda não possui visitantes cadastrados.',
        icon: Icons.person_outline,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadVisitors,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        itemCount: _visitors.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (_, i) {
          final v = _visitors[i];
          final name = v['name'] as String? ?? '';
          final phone = v['phone'] as String? ?? '';
          final status = v['status'] as String? ?? '';
          final initials = name
              .split(' ')
              .where((e) => e.isNotEmpty)
              .map((e) => e[0])
              .take(2)
              .join();
          return AppCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                AppAvatar(initials: initials, size: 40),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: AppTypography.titleSmall),
                      if (phone.isNotEmpty)
                        Text(
                          phone,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const Spacer(),
          Text(value, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}

class _AttendanceBadge extends StatelessWidget {
  const _AttendanceBadge({required this.rate});

  final double rate;

  @override
  Widget build(BuildContext context) {
    final color = rate >= 75
        ? AppColors.success
        : rate >= 50
        ? AppColors.warning
        : AppColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Média ${rate.toStringAsFixed(0)}%',
        style: AppTypography.labelSmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatMini extends StatelessWidget {
  const _StatMini({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.titleSmall.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      'novo' => ('Novo', AppColors.primary),
      'em_acompanhamento' => ('Acompanhamento', AppColors.warning),
      'integrado' => ('Integrado', AppColors.success),
      'inativo' => ('Inativo', AppColors.grey400),
      _ => (status, AppColors.grey400),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: AppTypography.labelSmall.copyWith(color: color),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            error,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
          ),
          const SizedBox(height: AppSpacing.base),
          AppButton(
            label: 'Tentar novamente',
            variant: AppButtonVariant.outline,
            isFullWidth: false,
            onPressed: onRetry,
          ),
        ],
      ),
    );
  }
}
