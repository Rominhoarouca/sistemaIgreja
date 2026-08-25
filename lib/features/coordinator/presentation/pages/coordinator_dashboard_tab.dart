import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/stat_detail_page.dart';
import '../../../dashboard/presentation/widgets/integration_line_chart.dart';
import '../../../../injection/injection.dart';

/// Contato alcançável pelo coordenador via WhatsApp: supervisor ou líder da
/// sua coordenação, ou visitante/membro das células desses líderes.
class _Contact {
  _Contact({
    required this.id,
    required this.name,
    required this.phone,
    required this.kind,
    required this.supervisorId,
    this.leaderName = '',
    this.cellName = '',
  });

  final String id;
  final String name;
  final String phone;
  final String kind; // 'supervisor' | 'lider' | 'visitante' | 'membro'
  final String supervisorId;
  final String leaderName;
  final String cellName;

  String get kindLabel => switch (kind) {
    'supervisor' => 'Supervisor',
    'lider' => 'Líder',
    'membro' => 'Membro',
    _ => 'Visitante',
  };
}

class _SupervisorSummary {
  _SupervisorSummary({required this.id, required this.name});

  final String id;
  final String name;
  int leaderCount = 0;
  int cellCount = 0;
  int visitorCount = 0;
  int memberCount = 0;
}

/// Home do Coordenador — evolução dos supervisores, líderes, células e
/// visitantes da sua coordenação + WhatsApp restrito a esse contexto.
class CoordinatorDashboardTab extends StatefulWidget {
  const CoordinatorDashboardTab({super.key});

  @override
  State<CoordinatorDashboardTab> createState() =>
      _CoordinatorDashboardTabState();
}

class _CoordinatorDashboardTabState extends State<CoordinatorDashboardTab> {
  late final Dio _dio;
  bool _loading = true;
  String? _error;

  List<_SupervisorSummary> _supervisors = [];
  List<_Contact> _contacts = [];
  int _totalLeaders = 0;
  int _totalCells = 0;
  int _totalVisitors = 0;
  int _integrated = 0;

  /// Últimos 6 meses: [{month, total, integrated}] para o gráfico.
  List<Map<String, dynamic>> _months = [];

  @override
  void initState() {
    super.initState();
    _dio = getIt<DioClient>().dio;
    _loadData();
  }

  static const _monthLabels = [
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];

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
      final supervisorsRaw =
          ((results[0].data as Map<String, dynamic>)['supervisors'] as List? ??
                  [])
              .cast<Map<String, dynamic>>();
      final leadersRaw =
          ((results[1].data as Map<String, dynamic>)['leaders'] as List? ?? [])
              .cast<Map<String, dynamic>>();

      final supervisors = <String, _SupervisorSummary>{};
      final contacts = <_Contact>[];
      final visitorDates = <({DateTime date, bool integrated})>[];
      var totalCells = 0;
      var totalVisitors = 0;
      var integrated = 0;

      for (final s in supervisorsRaw) {
        final summary = _SupervisorSummary(
          id: s['id'] as String,
          name: (s['name'] as String?) ?? '',
        );
        supervisors[summary.id] = summary;
        contacts.add(
          _Contact(
            id: summary.id,
            name: summary.name,
            phone: (s['phone'] as String?) ?? '',
            kind: 'supervisor',
            supervisorId: summary.id,
          ),
        );
      }

      await Future.wait(
        leadersRaw.map((l) async {
          final leaderId = l['id'] as String;
          final leaderName = (l['name'] as String?) ?? '';
          final supervisorId = (l['supervisorId'] as String?) ?? '';
          final summary = supervisors[supervisorId];
          summary?.leaderCount++;
          contacts.add(
            _Contact(
              id: leaderId,
              name: leaderName,
              phone: (l['phone'] as String?) ?? '',
              kind: 'lider',
              supervisorId: supervisorId,
              leaderName: leaderName,
            ),
          );

          final cellsResp = await _dio.get(
            '/cells',
            queryParameters: {'leaderId': leaderId},
          );
          final cells =
              ((cellsResp.data as Map<String, dynamic>)['cells'] as List? ?? [])
                  .cast<Map<String, dynamic>>();
          summary?.cellCount += cells.length;
          totalCells += cells.length;

          await Future.wait(
            cells.map((c) async {
              final cellId = c['id'] as String;
              final cellName = (c['name'] as String?) ?? '';
              final r = await Future.wait([
                _dio.get('/visitors', queryParameters: {'cellId': cellId}),
                _dio.get('/cells/$cellId/members'),
              ]);
              final visitors =
                  ((r[0].data as Map<String, dynamic>)['data'] as List? ?? [])
                      .cast<Map<String, dynamic>>();
              final members =
                  ((r[1].data as Map<String, dynamic>)['members'] as List? ??
                          [])
                      .cast<Map<String, dynamic>>();

              summary?.visitorCount += visitors.length;
              summary?.memberCount += members.length;
              totalVisitors += visitors.length;

              for (final v in visitors) {
                final isIntegrated = (v['status'] as String?) == 'integrado';
                if (isIntegrated) integrated++;
                final created = DateTime.tryParse(
                  (v['createdAt'] as String?) ?? '',
                );
                if (created != null) {
                  visitorDates.add((date: created, integrated: isIntegrated));
                }
                contacts.add(
                  _Contact(
                    id: v['id'] as String,
                    name: (v['name'] as String?) ?? 'Sem nome',
                    phone: (v['phone'] as String?) ?? '',
                    kind: 'visitante',
                    supervisorId: supervisorId,
                    leaderName: leaderName,
                    cellName: cellName,
                  ),
                );
              }
              for (final m in members) {
                contacts.add(
                  _Contact(
                    id: m['id'] as String,
                    name: (m['name'] as String?) ?? 'Sem nome',
                    phone: (m['phone'] as String?) ?? '',
                    kind: 'membro',
                    supervisorId: supervisorId,
                    leaderName: leaderName,
                    cellName: cellName,
                  ),
                );
              }
            }),
          );
        }),
      );

      // Evolução: buckets dos últimos 6 meses (cadastros × integrados).
      final now = DateTime.now();
      final months = <Map<String, dynamic>>[];
      for (var i = 5; i >= 0; i--) {
        final m = DateTime(now.year, now.month - i);
        final inMonth = visitorDates.where(
          (v) => v.date.year == m.year && v.date.month == m.month,
        );
        months.add({
          'month': _monthLabels[m.month - 1],
          'total': inMonth.length,
          'integrated': inMonth.where((v) => v.integrated).length,
        });
      }

      final ranking = supervisors.values.toList()
        ..sort((a, b) => b.visitorCount.compareTo(a.visitorCount));

      if (!mounted) return;
      setState(() {
        _supervisors = ranking;
        _contacts = contacts;
        _totalLeaders = leadersRaw.length;
        _totalCells = totalCells;
        _totalVisitors = totalVisitors;
        _integrated = integrated;
        _months = months;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar dados da coordenação';
        _loading = false;
      });
    }
  }

  void _openWhatsappSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CoordinatorWhatsappSheet(
        supervisors: _supervisors,
        contacts: _contacts,
      ),
    );
  }

  // ── Detalhe dos KPIs ───────────────────────────────────────────────────

  String _supervisorName(String supervisorId) => _supervisors
      .firstWhere(
        (s) => s.id == supervisorId,
        orElse: () => _SupervisorSummary(id: '', name: '—'),
      )
      .name;

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

  void _openSupervisorsDetail() {
    final supervisors = [..._supervisors]
      ..sort((a, b) => a.name.compareTo(b.name));
    _openStatDetail(
      title: 'Supervisores',
      icon: Icons.supervisor_account_outlined,
      headerValue: '${supervisors.length}',
      subtitle: 'Supervisores da sua coordenação',
      columns: const ['Supervisor', 'Líderes', 'Células', 'Visitantes'],
      rows: supervisors
          .map(
            (s) => [
              s.name,
              '${s.leaderCount}',
              '${s.cellCount}',
              '${s.visitorCount}',
            ],
          )
          .toList(),
    );
  }

  void _openLeadersDetail() {
    final leaders = _contacts.where((c) => c.kind == 'lider').toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    _openStatDetail(
      title: 'Líderes',
      icon: Icons.record_voice_over_outlined,
      headerValue: '$_totalLeaders',
      subtitle: 'Líderes da sua coordenação',
      columns: const ['Nome', 'Telefone', 'Supervisor'],
      rows: leaders
          .map(
            (l) => [
              l.name,
              l.phone.isEmpty ? '—' : l.phone,
              _supervisorName(l.supervisorId),
            ],
          )
          .toList(),
    );
  }

  void _openCellsDetail() {
    final supervisors = _supervisors.where((s) => s.cellCount > 0).toList()
      ..sort((a, b) => b.cellCount.compareTo(a.cellCount));
    _openStatDetail(
      title: 'Células',
      icon: Icons.groups_2_outlined,
      headerValue: '$_totalCells',
      subtitle: 'Células por supervisor da coordenação',
      columns: const ['Supervisor', 'Células', 'Membros', 'Visitantes'],
      rows: supervisors
          .map(
            (s) => [
              s.name,
              '${s.cellCount}',
              '${s.memberCount}',
              '${s.visitorCount}',
            ],
          )
          .toList(),
    );
  }

  void _openVisitorsDetail() {
    final visitors = _contacts.where((c) => c.kind == 'visitante').toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    _openStatDetail(
      title: 'Visitantes',
      icon: Icons.people_outline,
      headerValue: '$_totalVisitors',
      subtitle: 'Visitantes das células da coordenação',
      columns: const ['Nome', 'Telefone', 'Célula', 'Líder'],
      rows: visitors
          .map(
            (v) => [
              v.name,
              v.phone.isEmpty ? '—' : v.phone,
              v.cellName.isEmpty ? '—' : v.cellName,
              v.leaderName.isEmpty ? '—' : v.leaderName,
            ],
          )
          .toList(),
    );
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
    if (_supervisors.isEmpty && _totalLeaders == 0) {
      return const Center(
        child: AppEmptyState(
          title: 'Nenhum supervisor vinculado',
          subtitle:
              'Solicite ao administrador que associe supervisores à sua coordenação.',
          icon: Icons.supervisor_account_outlined,
        ),
      );
    }

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
                label: 'Supervisores',
                value: '${_supervisors.length}',
                icon: Icons.supervisor_account_outlined,
                onTap: _openSupervisorsDetail,
              ),
              StatCard(
                label: 'Líderes',
                value: '$_totalLeaders',
                icon: Icons.record_voice_over_outlined,
                onTap: _openLeadersDetail,
              ),
              StatCard(
                label: 'Células',
                value: '$_totalCells',
                icon: Icons.groups_2_outlined,
                onTap: _openCellsDetail,
              ),
              StatCard(
                label: 'Visitantes',
                value: '$_totalVisitors',
                icon: Icons.people_outline,
                subtitle: _totalVisitors > 0
                    ? '${(_integrated / _totalVisitors * 100).round()}% integrados'
                    : null,
                onTap: _openVisitorsDetail,
              ),
            ]),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Ações rápidas ────────────────────────────────────────────
          AppSectionHeader(title: 'Ações rápidas'),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
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
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Evolução ─────────────────────────────────────────────────
          AppSectionHeader(title: 'Evolução de visitantes (6 meses)'),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            child: _months.every((m) => (m['total'] as int) == 0)
                ? SizedBox(
                    height: 160,
                    child: Center(
                      child: Text(
                        'Sem cadastros de visitantes no período.',
                        style: AppTypography.bodySmall.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IntegrationLineChart(months: _months),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: [
                          _legendDot(theme, AppColors.primary, 'Cadastrados'),
                          const SizedBox(width: AppSpacing.base),
                          _legendDot(theme, AppColors.success, 'Integrados'),
                        ],
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: AppSpacing.xl),

          // ── Supervisores (ranking por visitantes) ────────────────────
          AppSectionHeader(title: 'Desempenho dos supervisores'),
          const SizedBox(height: AppSpacing.sm),
          if (_supervisors.isEmpty)
            AppCard(
              child: Text(
                'Nenhum supervisor vinculado à coordenação.',
                style: AppTypography.bodyMedium.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ..._supervisors.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: AppCard(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      AppAvatar(
                        initials: s.name
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
                            Text(s.name, style: AppTypography.titleSmall),
                            const SizedBox(height: 2),
                            Text(
                              '${s.leaderCount} líder(es) · ${s.cellCount} célula(s) · ${s.memberCount} membros',
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
                            '${s.visitorCount}',
                            style: AppTypography.titleMedium.copyWith(
                              color: theme.brightness == Brightness.dark
                                  ? AppColors.linkDark
                                  : AppColors.primary,
                            ),
                          ),
                          Text(
                            'visitantes',
                            style: AppTypography.labelSmall.copyWith(
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
          const SizedBox(height: AppSpacing.xl2),
        ],
      ),
    );
  }

  Widget _legendDot(ThemeData theme, Color color, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: AppSpacing.xs),
      Text(
        label,
        style: AppTypography.labelSmall.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// WhatsApp — envio restrito à coordenação
// ═════════════════════════════════════════════════════════════════════════════

class _CoordinatorWhatsappSheet extends StatefulWidget {
  const _CoordinatorWhatsappSheet({
    required this.supervisors,
    required this.contacts,
  });

  final List<_SupervisorSummary> supervisors;
  final List<_Contact> contacts;

  @override
  State<_CoordinatorWhatsappSheet> createState() =>
      _CoordinatorWhatsappSheetState();
}

class _CoordinatorWhatsappSheetState extends State<_CoordinatorWhatsappSheet> {
  String? _supervisorFilter; // null = todos
  int _typeFilter = 0;
  final _msgCtrl = TextEditingController();
  final Set<String> _selectedKeys = {};
  bool _sending = false;
  int _sentCount = 0;

  static const _typeLabels = [
    'Todos',
    'Supervisores',
    'Líderes',
    'Visitantes',
    'Membros',
  ];
  static const _typeKinds = [
    null,
    'supervisor',
    'lider',
    'visitante',
    'membro',
  ];

  @override
  void dispose() {
    _msgCtrl.dispose();
    super.dispose();
  }

  String _keyOf(_Contact c) => '${c.kind}-${c.id}';

  List<_Contact> get _filtered => widget.contacts.where((c) {
    if (_supervisorFilter != null && c.supervisorId != _supervisorFilter) {
      return false;
    }
    final kind = _typeKinds[_typeFilter];
    if (kind != null && c.kind != kind) return false;
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
      .replaceAll('{celula}', c.cellName.isEmpty ? 'sua célula' : c.cellName)
      .replaceAll('{lider}', c.leaderName.isEmpty ? 'seu líder' : c.leaderName);

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
                // ── Filtro por supervisor ──────────────────────────────
                if (widget.supervisors.length > 1) ...[
                  Text(
                    'SUPERVISOR',
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
                          label: const Text('Todos'),
                          selected: _supervisorFilter == null,
                          showCheckmark: false,
                          onSelected: (_) =>
                              setState(() => _supervisorFilter = null),
                        ),
                        for (final s in widget.supervisors) ...[
                          const SizedBox(width: AppSpacing.sm),
                          FilterChip(
                            label: Text(s.name),
                            selected: _supervisorFilter == s.id,
                            showCheckmark: false,
                            onSelected: (_) =>
                                setState(() => _supervisorFilter = s.id),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.base),
                ],

                // ── Filtro por tipo ────────────────────────────────────
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
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
                              [
                                filtered[i].kindLabel,
                                if (filtered[i].cellName.isNotEmpty)
                                  filtered[i].cellName,
                                if (filtered[i].phone.isEmpty) 'sem telefone',
                              ].join(' · '),
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
                    for (final v in const ['{nome}', '{celula}', '{lider}'])
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
                    hintText: 'Olá {nome}! A célula {celula} do líder {lider}…',
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
