import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../../../injection/injection.dart';
import '../../../../shared/utils/app_snackbar.dart';

class _PendingCell {
  _PendingCell({
    required this.id,
    required this.name,
    required this.neighborhood,
    required this.dayOfWeek,
    required this.time,
  });

  final String id;
  final String name;
  final String neighborhood;
  final String dayOfWeek;
  final String time;

  factory _PendingCell.fromJson(Map<String, dynamic> j) => _PendingCell(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    neighborhood: j['neighborhood'] as String? ?? '',
    dayOfWeek: j['dayOfWeek'] as String? ?? '',
    time: j['time'] as String? ?? '',
  );

  String get subtitle => [
    if (neighborhood.isNotEmpty) neighborhood,
    if (dayOfWeek.isNotEmpty) dayOfWeek,
    if (time.isNotEmpty) time,
  ].join(' · ');
}

class _PendingLeader {
  _PendingLeader({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;

  factory _PendingLeader.fromJson(Map<String, dynamic> j) => _PendingLeader(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    email: j['email'] as String? ?? '',
  );

  String get initials => name
      .split(' ')
      .where((e) => e.isNotEmpty)
      .map((e) => e[0])
      .take(2)
      .join();
}

/// Vínculos pendentes: células sem líder e líderes sem célula.
///
/// Existe porque os dois cadastros deixaram de depender um do outro — sem uma
/// tela que mostre quem ficou sem par, a ponta solta some de vista.
class AdminPendingLinksPage extends StatefulWidget {
  const AdminPendingLinksPage({super.key});

  @override
  State<AdminPendingLinksPage> createState() => _AdminPendingLinksPageState();
}

class _AdminPendingLinksPageState extends State<AdminPendingLinksPage> {
  late final Dio _dio;

  List<_PendingCell> _cells = [];
  List<_PendingLeader> _leaders = [];
  bool _loading = true;
  String? _error;
  String? _savingId;

  @override
  void initState() {
    super.initState();
    _dio = getIt<DioClient>().dio;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await _dio.get('/cells/pending-links');
      final data = resp.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _cells =
            (data['cellsWithoutLeader'] as List?)
                ?.cast<Map<String, dynamic>>()
                .map(_PendingCell.fromJson)
                .toList() ??
            [];
        _leaders =
            (data['leadersWithoutCell'] as List?)
                ?.cast<Map<String, dynamic>>()
                .map(_PendingLeader.fromJson)
                .toList() ??
            [];
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Não foi possível carregar os vínculos pendentes';
      });
    }
  }

  /// Vincula os dois lados. É a mesma operação vista das duas listas, por isso
  /// recebe célula e líder em vez de um "sentido".
  Future<void> _link({
    required String cellId,
    required String leaderId,
    required String busyId,
  }) async {
    setState(() => _savingId = busyId);
    try {
      await _dio.patch('/cells/$cellId', data: {'leaderId': leaderId});
      if (!mounted) return;
      AppSnackbar.success('Vínculo criado');
      await _load();
    } on DioException catch (e) {
      if (!mounted) return;
      AppSnackbar.error(
        e.response?.data?['error']?['message'] as String? ??
            'Não foi possível criar o vínculo',
      );
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  Future<void> _pickLeaderFor(_PendingCell cell) async {
    if (_leaders.isEmpty) {
      AppSnackbar.error('Nenhum líder sem célula disponível');
      return;
    }
    final leaderId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PickSheet(
        title: 'Líder para ${cell.name}',
        items: [
          for (final l in _leaders) (id: l.id, title: l.name, subtitle: l.email),
        ],
      ),
    );
    if (leaderId == null) return;
    await _link(cellId: cell.id, leaderId: leaderId, busyId: cell.id);
  }

  Future<void> _pickCellFor(_PendingLeader leader) async {
    if (_cells.isEmpty) {
      AppSnackbar.error('Nenhuma célula sem líder disponível');
      return;
    }
    final cellId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PickSheet(
        title: 'Célula para ${leader.name}',
        items: [
          for (final c in _cells)
            (id: c.id, title: c.name, subtitle: c.subtitle),
        ],
      ),
    );
    if (cellId == null) return;
    await _link(cellId: cellId, leaderId: leader.id, busyId: leader.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Vínculos pendentes')),
      body: _loading
          ? const Center(child: AppLoadingIndicator(size: 32))
          : _error != null
          ? AppErrorState(message: _error!, onRetry: _load)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
                children: [
                  _section(
                    title: 'Células sem líder',
                    count: _cells.length,
                    emptyMessage: 'Toda célula tem líder.',
                    children: [
                      for (final cell in _cells)
                        AppCard(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.groups_2_outlined,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cell.name,
                                      style: AppTypography.titleSmall,
                                    ),
                                    if (cell.subtitle.isNotEmpty)
                                      Text(
                                        cell.subtitle,
                                        style: AppTypography.bodySmall
                                            .copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                      ),
                                  ],
                                ),
                              ),
                              _linkButton(
                                busy: _savingId == cell.id,
                                onPressed: () => _pickLeaderFor(cell),
                                label: 'Definir líder',
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _section(
                    title: 'Líderes sem célula',
                    count: _leaders.length,
                    emptyMessage: 'Todo líder tem célula.',
                    children: [
                      for (final leader in _leaders)
                        AppCard(
                          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Row(
                            children: [
                              AppAvatar(initials: leader.initials),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      leader.name,
                                      style: AppTypography.titleSmall,
                                    ),
                                    Text(
                                      leader.email,
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _linkButton(
                                busy: _savingId == leader.id,
                                onPressed: () => _pickCellFor(leader),
                                label: 'Definir célula',
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl2),
                ],
              ),
            ),
    );
  }

  Widget _linkButton({
    required bool busy,
    required VoidCallback onPressed,
    required String label,
  }) => busy
      ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : TextButton(onPressed: onPressed, child: Text(label));

  Widget _section({
    required String title,
    required int count,
    required String emptyMessage,
    required List<Widget> children,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Expanded(child: Text(title, style: AppTypography.titleMedium)),
          AppBadge(
            label: '$count',
            variant: count == 0
                ? AppBadgeVariant.success
                : AppBadgeVariant.warning,
            size: AppBadgeSize.sm,
          ),
        ],
      ),
      const SizedBox(height: AppSpacing.sm),
      if (children.isEmpty)
        Text(
          emptyMessage,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        )
      else
        ...children,
    ],
  );
}

/// Lista simples de escolha usada nos dois sentidos do vínculo.
class _PickSheet extends StatelessWidget {
  const _PickSheet({required this.title, required this.items});

  final String title;
  final List<({String id, String title, String subtitle})> items;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) => ListTile(
                  title: Text(items[i].title),
                  subtitle: items[i].subtitle.isEmpty
                      ? null
                      : Text(items[i].subtitle),
                  onTap: () => Navigator.of(context).pop(items[i].id),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
