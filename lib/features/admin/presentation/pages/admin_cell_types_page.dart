import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../../../injection/injection.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class _CellTypeItem {
  const _CellTypeItem({required this.id, required this.name, this.description});

  final String id;
  final String name;
  final String? description;

  factory _CellTypeItem.fromJson(Map<String, dynamic> json) => _CellTypeItem(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Page
// ─────────────────────────────────────────────────────────────────────────────

class AdminCellTypesPage extends StatefulWidget {
  const AdminCellTypesPage({super.key});

  @override
  State<AdminCellTypesPage> createState() => _AdminCellTypesPageState();
}

class _AdminCellTypesPageState extends State<AdminCellTypesPage> {
  late final Dio _dio;
  bool _loading = true;
  String? _error;
  List<_CellTypeItem> _cellTypes = [];

  @override
  void initState() {
    super.initState();
    _dio = getIt<DioClient>().dio;
    _loadCellTypes();
  }

  Future<void> _loadCellTypes() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await _dio.get('/cell-types');
      final data =
          (resp.data as Map<String, dynamic>)['cellTypes'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _cellTypes = data
            .map((e) => _CellTypeItem.fromJson(e as Map<String, dynamic>))
            .toList();
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar tipos de célula';
        _loading = false;
      });
    }
  }

  Future<void> _delete(_CellTypeItem item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir tipo de célula'),
        content: Text(
          'Deseja excluir "${item.name}"? As células vinculadas perderão este tipo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _dio.delete('/cell-types/${item.id}');
      _loadCellTypes();
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?['message'] as String? ??
                'Erro ao excluir tipo de célula',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showFormSheet({_CellTypeItem? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CellTypeFormSheet(dio: _dio, existing: existing),
    );
    if (saved == true) _loadCellTypes();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tipos de Célula')),
      body: _loading
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
                    onPressed: _loadCellTypes,
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadCellTypes,
              child: _cellTypes.isEmpty
                  ? ListView(
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpacing.xl),
                            child: AppEmptyState(
                              title: 'Nenhum tipo de célula',
                              subtitle:
                                  'Crie o primeiro tipo usando o botão abaixo.',
                              icon: Icons.category_outlined,
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
                      itemCount: _cellTypes.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (_, i) {
                        final item = _cellTypes[i];
                        return AppCard(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusSm,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.category_outlined,
                                  color: AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.name,
                                      style: AppTypography.titleSmall,
                                    ),
                                    if (item.description != null &&
                                        item.description!.isNotEmpty)
                                      Text(
                                        item.description!,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.edit_outlined,
                                  color: AppColors.grey500,
                                ),
                                onPressed: () => _showFormSheet(existing: item),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.error,
                                ),
                                onPressed: () => _delete(item),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormSheet(),
        icon: const Icon(Icons.add),
        label: const Text('Novo tipo'),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CellTypeFormSheet extends StatefulWidget {
  const _CellTypeFormSheet({required this.dio, this.existing});

  final Dio dio;
  final _CellTypeItem? existing;

  @override
  State<_CellTypeFormSheet> createState() => _CellTypeFormSheetState();
}

class _CellTypeFormSheetState extends State<_CellTypeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _descCtrl = TextEditingController(text: widget.existing?.description ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final body = {
        'name': _nameCtrl.text.trim(),
        if (_descCtrl.text.trim().isNotEmpty)
          'description': _descCtrl.text.trim(),
      };
      if (widget.existing != null) {
        await widget.dio.patch(
          '/cell-types/${widget.existing!.id}',
          data: body,
        );
      } else {
        await widget.dio.post('/cell-types', data: body);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?['message'] as String? ??
                'Erro ao salvar tipo de célula',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
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
            Text(
              isEdit ? 'Editar Tipo de Célula' : 'Novo Tipo de Célula',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: AppSpacing.base),
            AppTextField(
              label: 'Nome *',
              controller: _nameCtrl,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Informe o nome' : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              label: 'Descrição (opcional)',
              controller: _descCtrl,
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.base),
            AppButton(
              label: _saving ? 'Salvando...' : (isEdit ? 'Salvar' : 'Criar'),
              onPressed: _saving ? null : _save,
              isLoading: _saving,
            ),
          ],
        ),
      ),
    );
  }
}
