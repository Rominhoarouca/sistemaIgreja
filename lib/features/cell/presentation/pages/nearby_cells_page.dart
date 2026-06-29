import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/auth_storage.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';

/// Nearby Cells page — RF02 / RF03
/// Shows list of nearby cell groups with distance
class NearbyCellsPage extends StatefulWidget {
  const NearbyCellsPage({super.key, this.visitorName});

  final String? visitorName;

  @override
  State<NearbyCellsPage> createState() => _NearbyCellsPageState();
}

class _NearbyCellsPageState extends State<NearbyCellsPage> {
  late final Dio _dio;
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String? _error;
  String _query = '';
  List<Map<String, dynamic>> _cells = [];

  @override
  void initState() {
    super.initState();
    _dio = DioClient(AuthStorage()).dio;
    _loadCells();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCells() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final resp = await _dio.get('/cells');
      final cells = (resp.data as Map<String, dynamic>)['cells'] as List;
      if (!mounted) return;
      setState(() {
        _cells = cells.cast<Map<String, dynamic>>();
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar células';
        _loading = false;
      });
    }
  }

  List<Map<String, dynamic>> get _filteredCells {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _cells;
    return _cells.where((cell) {
      final name = ((cell['name'] as String?) ?? '').toLowerCase();
      final neighborhood = ((cell['neighborhood'] as String?) ?? '')
          .toLowerCase();
      return name.contains(q) || neighborhood.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredCells;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Células Próximas'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ── Sub-header ─────────────────────────────────────────────────
          Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pagePaddingH,
              0,
              AppSpacing.pagePaddingH,
              AppSpacing.base,
            ),
            child: Text(
              widget.visitorName != null
                  ? 'Olá, ${widget.visitorName!.split(' ').first}! Encontramos estas células perto de você:'
                  : 'Encontramos estas células perto de você:',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.white.withValues(alpha: 0.9),
              ),
            ),
          ),

          // ── Search ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: AppSearchField(
              hint: 'Filtrar por bairro ou nome...',
              controller: _searchCtrl,
              onChanged: (value) => setState(() => _query = value),
            ),
          ),

          // ── Cell list ─────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _error!,
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.error,
                            ),
                            textAlign: TextAlign.center,
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
                    ),
                  )
                : filtered.isEmpty
                ? Center(
                    child: Text(
                      'Nenhuma célula encontrada',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.pagePaddingH,
                    ),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) =>
                        _CellCard(cell: filtered[index]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CellCard extends StatelessWidget {
  const _CellCard({required this.cell});

  final Map<String, dynamic> cell;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () {},
      child: Row(
        children: [
          // Icon
          Container(
            width: AppSpacing.avatarLg,
            height: AppSpacing.avatarLg,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: const Icon(
              Icons.groups_2_outlined,
              color: AppColors.primary,
              size: AppSpacing.iconLg,
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (cell['name'] as String?) ?? 'Célula',
                  style: AppTypography.titleSmall,
                ),
                const SizedBox(height: AppSpacing.xs2),
                Text(
                  'Líder: ${(cell['leaderName'] as String?) ?? 'Sem líder'}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs2),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: AppColors.grey400,
                    ),
                    const SizedBox(width: AppSpacing.xs2),
                    Text(
                      '${_dayShort((cell['dayOfWeek'] as String?) ?? '')} · ${(cell['time'] as String?) ?? '--:--'}',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Distance + Select
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AppBadge(
                label:
                    '${cell['currentCount'] ?? 0}/${cell['maxCapacity'] ?? '-'}',
                variant: AppBadgeVariant.success,
                icon: Icons.groups_2_outlined,
                size: AppBadgeSize.sm,
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Selecionar',
                size: AppButtonSize.sm,
                isFullWidth: false,
                onPressed: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _dayShort(String dayOfWeek) {
    return switch (dayOfWeek) {
      'segunda' => 'Seg',
      'terca' => 'Ter',
      'quarta' => 'Qua',
      'quinta' => 'Qui',
      'sexta' => 'Sex',
      'sabado' => 'Sab',
      'domingo' => 'Dom',
      _ => 'Dia',
    };
  }
}
