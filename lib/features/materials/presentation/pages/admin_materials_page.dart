import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/app_snackbar.dart';
import '../../../../injection/injection.dart';

/// Admin Materials page — load/upload/delete/view materials via API + MinIO.
class AdminMaterialsPage extends StatefulWidget {
  const AdminMaterialsPage({super.key});

  @override
  State<AdminMaterialsPage> createState() => _AdminMaterialsPageState();
}

// ── Data models ──────────────────────────────────────────────────────────────

class _MaterialData {
  final String id;
  final String cellId;
  final String title;
  final String type;
  final int sizeBytes;
  final DateTime uploadedAt;

  const _MaterialData({
    required this.id,
    required this.cellId,
    required this.title,
    required this.type,
    required this.sizeBytes,
    required this.uploadedAt,
  });

  factory _MaterialData.fromJson(Map<String, dynamic> j) => _MaterialData(
    id: j['id'] as String,
    cellId: j['cellId'] as String,
    title: j['title'] as String,
    type: j['fileType'] as String,
    sizeBytes: j['sizeBytes'] as int,
    uploadedAt: DateTime.parse(j['uploadedAt'] as String),
  );

  String get formattedSize {
    if (sizeBytes >= 1024 * 1024) {
      return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
  }
}

class _CellOption {
  final String id;
  final String name;
  const _CellOption({required this.id, required this.name});
}

class _GroupedMaterial {
  final String title;
  final String type;
  final int sizeBytes;
  final DateTime uploadedAt;
  final List<String> materialIds;
  final List<String> cellIds;
  const _GroupedMaterial({
    required this.title,
    required this.type,
    required this.sizeBytes,
    required this.uploadedAt,
    required this.materialIds,
    required this.cellIds,
  });

  bool isAllCells(int totalCells) => cellIds.length >= totalCells;
}

class _AdminMaterialsPageState extends State<AdminMaterialsPage> {
  /// Limite de tamanho de upload — abaixo do limite do backend (100 MB) pra
  /// barrar no cliente antes de gastar banda subindo um arquivo que vai
  /// ser rejeitado de qualquer forma.
  static const int _maxUploadBytes = 50 * 1024 * 1024;

  final _searchCtrl = TextEditingController();
  late final Dio _dio;

  String _query = '';
  bool _isLoading = true;
  bool _isUploading = false;
  String? _error;
  List<_MaterialData> _materials = [];
  List<_CellOption> _cells = [];
  List<Map<String, dynamic>> _cellTypes = [];
  final Map<String, bool> _opening = {};

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
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _dio.get('/materials'),
        _dio.get('/cells'),
        _dio.get('/cell-types'),
      ]);
      final mData =
          (results[0].data as Map<String, dynamic>)['materials'] as List;
      final cData = (results[1].data as Map<String, dynamic>)['cells'] as List;
      final tData =
          (results[2].data as Map<String, dynamic>)['cellTypes'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _materials = mData
            .map((m) => _MaterialData.fromJson(m as Map<String, dynamic>))
            .toList();
        _cells = cData
            .map(
              (c) =>
                  _CellOption(id: c['id'] as String, name: c['name'] as String),
            )
            .toList();
        _cellTypes = tData.cast<Map<String, dynamic>>();
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = extractDioErrorMessage(
          e,
          fallback: 'Erro ao carregar materiais',
        );
        _isLoading = false;
      });
    }
  }

  List<_GroupedMaterial> get _grouped {
    final Map<String, _GroupedMaterial> map = {};
    for (final m in _materials) {
      // group by title + size + type to avoid naive duplicates
      final key = '${m.title}|${m.sizeBytes}|${m.type}';
      final existing = map[key];
      if (existing == null) {
        map[key] = _GroupedMaterial(
          title: m.title,
          type: m.type,
          sizeBytes: m.sizeBytes,
          uploadedAt: m.uploadedAt,
          materialIds: [m.id],
          cellIds: [m.cellId],
        );
      } else {
        map[key] = _GroupedMaterial(
          title: existing.title,
          type: existing.type,
          sizeBytes: existing.sizeBytes,
          uploadedAt: existing.uploadedAt,
          materialIds: [...existing.materialIds, m.id],
          cellIds: [...existing.cellIds, m.cellId],
        );
      }
    }
    final list = map.values.toList();
    // apply search query
    final q = _query.toLowerCase();
    if (q.isNotEmpty) {
      return list.where((g) => g.title.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  // ── Upload ────────────────────────────────────────────────────────────────

  Future<void> _uploadMaterial() async {
    if (_cells.isEmpty) {
      AppSnackbar.warning('Nenhuma célula cadastrada para associar material');
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'mp4', 'mov'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    if (file.size > _maxUploadBytes) {
      AppSnackbar.warning(
        'Arquivo muito grande (${_formatBytes(file.size)}). '
        'O limite é ${_formatBytes(_maxUploadBytes)}. Envio bloqueado.',
      );
      return;
    }

    if (!mounted) return;
    final params = await showDialog<_UploadParams>(
      context: context,
      builder: (ctx) => _UploadDialog(
        defaultTitle: file.name.replaceAll(RegExp(r'\.\w+$'), ''),
        cells: _cells,
        cellTypes: _cellTypes,
      ),
    );
    if (params == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = file.bytes;
      if (bytes == null) throw Exception('Não foi possível ler o arquivo');
      final Map<String, dynamic> map = {
        'file': MultipartFile.fromBytes(bytes, filename: file.name),
        'title': params.title,
      };
      if (params.allCells) {
        map['allCells'] = 'true';
      } else if (params.cellTypeId != null) {
        map['cellTypeId'] = params.cellTypeId!;
      } else {
        map['cellIds'] = jsonEncode(params.selectedCellIds);
      }
      final formData = FormData.fromMap(map);
      await _dio.post('/materials', data: formData);
      if (!mounted) return;
      setState(() => _isUploading = false);
      AppSnackbar.success('"${params.title}" enviado com sucesso!');
      _loadData();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      AppSnackbar.error(
        extractDioErrorMessage(e, fallback: 'Erro ao enviar arquivo'),
      );
    }
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  Future<void> _deleteMaterial(_MaterialData material) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir material'),
        content: Text(
          'Deseja excluir "${material.title}"? Esta ação não pode ser desfeita.',
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
      await _dio.delete('/materials/${material.id}');
      if (!mounted) return;
      setState(() => _materials.removeWhere((m) => m.id == material.id));
      AppSnackbar.success('Material excluído');
    } on DioException catch (e) {
      if (!mounted) return;
      AppSnackbar.error(
        extractDioErrorMessage(e, fallback: 'Erro ao excluir material'),
      );
    }
  }

  // ── View / Download ────────────────────────────────────────────────────────

  Future<void> _viewMaterial(_MaterialData material) async {
    setState(() => _opening[material.id] = true);
    try {
      final resp = await _dio.get('/materials/${material.id}/download-url');
      final url = resp.data['url'] as String;
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Não foi possível abrir o arquivo');
      }
    } on DioException catch (e) {
      AppSnackbar.error(
        extractDioErrorMessage(e, fallback: 'Erro ao obter URL do arquivo'),
      );
    } catch (e) {
      AppSnackbar.error(e.toString());
    } finally {
      if (mounted) setState(() => _opening.remove(material.id));
    }
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  IconData _typeIcon(String type) => switch (type) {
    'pdf' => Icons.picture_as_pdf_outlined,
    'ppt' => Icons.slideshow_outlined,
    'video' => Icons.play_circle_outline,
    'docx' => Icons.article_outlined,
    _ => Icons.attach_file_outlined,
  };

  Color _typeColor(String type) => switch (type) {
    'pdf' => AppColors.error,
    'ppt' => AppColors.warning,
    'video' => AppColors.info,
    _ => AppColors.primary,
  };

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Materiais'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Atualizar',
            onPressed: _isLoading ? null : _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.upload_file_outlined),
            tooltip: 'Enviar arquivo',
            onPressed: (_isUploading || _isLoading) ? null : _uploadMaterial,
          ),
        ],
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
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
            )
          : _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: (_isUploading || _isLoading) ? null : _uploadMaterial,
        icon: _isUploading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.white,
                ),
              )
            : const Icon(Icons.upload_file_outlined),
        label: const Text('Enviar arquivo'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
    );
  }

  Widget _buildList() {
    final grouped = _grouped;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePaddingH,
        AppSpacing.pagePaddingH,
        AppSpacing.pagePaddingH,
        100,
      ),
      children: [
        AppSearchField(
          hint: 'Pesquisar material...',
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: AppSpacing.base),
        if (_isUploading)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: AppCard(
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Text(
                    'Enviando arquivo...',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (grouped.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xl2),
            child: Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.folder_open_outlined,
                    size: 48,
                    color: AppColors.grey400,
                  ),
                  const SizedBox(height: AppSpacing.base),
                  Text(
                    'Nenhum material encontrado',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...grouped.map((g) {
            final representativeId = g.materialIds.first;
            final isOpening = _opening[representativeId] == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: GestureDetector(
                onTap: () {
                  // open a page that shows which cells this grouped material is available in
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => _MaterialTargetsPage(
                        title: g.title,
                        cells: _cells,
                        selectedCellIds: g.cellIds,
                      ),
                    ),
                  );
                },
                child: _AdminMaterialCard(
                  title: g.title,
                  subtitle:
                      '${g.type.toUpperCase()} · ${_formatBytes(g.sizeBytes)}',
                  typeIcon: _typeIcon(g.type),
                  typeColor: _typeColor(g.type),
                  isOpening: isOpening,
                  onView: () async {
                    // view uses the representative material id to obtain download url
                    final fake = _MaterialData(
                      id: representativeId,
                      cellId: g.cellIds.first,
                      title: g.title,
                      type: g.type,
                      sizeBytes: g.sizeBytes,
                      uploadedAt: g.uploadedAt,
                    );
                    await _viewMaterial(fake);
                  },
                  onDelete: () async {
                    // delete all underlying materials
                    for (final id in g.materialIds) {
                      await _deleteMaterial(
                        _MaterialData(
                          id: id,
                          cellId: g.cellIds.first,
                          title: g.title,
                          type: g.type,
                          sizeBytes: g.sizeBytes,
                          uploadedAt: g.uploadedAt,
                        ),
                      );
                    }
                    // reload grouped list
                    _loadData();
                  },
                ),
              ),
            );
          }),
      ],
    );
  }
}

class _MaterialTargetsPage extends StatelessWidget {
  const _MaterialTargetsPage({
    required this.title,
    required this.cells,
    required this.selectedCellIds,
  });

  final String title;
  final List<_CellOption> cells;
  final List<String> selectedCellIds;

  @override
  Widget build(BuildContext context) {
    final selectedSet = selectedCellIds.toSet();
    final allSelected = selectedSet.length >= cells.length;
    return Scaffold(
      appBar: AppBar(title: const Text('Disponibilidade do material')),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Título', style: AppTypography.labelMedium),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: TextEditingController(text: title),
              readOnly: true,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: AppSpacing.base),
            SwitchListTile(
              title: const Text('Disponível para todas as células'),
              value: allSelected,
              onChanged: null,
              subtitle: Text(
                allSelected ? 'Ativado' : 'Apenas células selecionadas',
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: cells.map((c) {
                    final selected = selectedSet.contains(c.id);
                    return FilterChip(
                      label: Text(c.name, overflow: TextOverflow.ellipsis),
                      selected: selected,
                      onSelected: null,
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Upload Dialog ────────────────────────────────────────────────────────────

class _UploadParams {
  final String title;
  final bool allCells;
  final List<String> selectedCellIds;
  final String? cellTypeId;
  const _UploadParams({
    required this.title,
    required this.allCells,
    required this.selectedCellIds,
    this.cellTypeId,
  });
}

class _UploadDialog extends StatefulWidget {
  const _UploadDialog({
    required this.defaultTitle,
    required this.cells,
    this.cellTypes = const [],
  });
  final String defaultTitle;
  final List<_CellOption> cells;
  final List<Map<String, dynamic>> cellTypes;

  @override
  State<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<_UploadDialog> {
  late final TextEditingController _titleCtrl;
  bool _allCells = true;
  String? _selectedCellTypeId;
  late final Set<String> _selectedIds;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.defaultTitle);
    _selectedIds = widget.cells
        .map((c) => c.id)
        .toSet(); // default: all selected
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  void _toggleSelectAll(bool select) {
    setState(() {
      if (select) {
        _selectedIds.addAll(widget.cells.map((c) => c.id));
      } else {
        _selectedIds.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enviar material'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: 'Título',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          SwitchListTile(
            title: const Text('Disponível para todas as células'),
            value: _allCells,
            onChanged: (v) => setState(() => _allCells = v),
            subtitle: const Text(
              'Se ativado, o material será disponibilizado para todas as células automaticamente.',
            ),
          ),
          if (!_allCells) ...[
            const SizedBox(height: AppSpacing.sm),
            if (widget.cellTypes.isNotEmpty) ...[
              DropdownButtonFormField<String?>(
                initialValue: _selectedCellTypeId,
                decoration: const InputDecoration(
                  labelText: 'Filtrar por tipo de célula (opcional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem(
                    value: null,
                    child: Text('Selecionar células individualmente'),
                  ),
                  ...widget.cellTypes.map(
                    (t) => DropdownMenuItem(
                      value: t['id'] as String,
                      child: Text(t['name'] as String),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedCellTypeId = v),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            if (_selectedCellTypeId == null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => _toggleSelectAll(true),
                    child: const Text('Selecionar todos'),
                  ),
                  TextButton(
                    onPressed: () => _toggleSelectAll(false),
                    child: const Text('Limpar'),
                  ),
                ],
              ),
              SizedBox(
                height: 160,
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: widget.cells.map((c) {
                      final selected = _selectedIds.contains(c.id);
                      return FilterChip(
                        label: Text(c.name, overflow: TextOverflow.ellipsis),
                        selected: selected,
                        onSelected: (s) => setState(
                          () => s
                              ? _selectedIds.add(c.id)
                              : _selectedIds.remove(c.id),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        TextButton(
          onPressed: () {
            final title = _titleCtrl.text.trim();
            if (title.isEmpty) return;
            if (!_allCells &&
                _selectedCellTypeId == null &&
                _selectedIds.isEmpty) {
              AppSnackbar.warning('Selecione ao menos uma célula ou tipo');
              return;
            }
            Navigator.pop(
              context,
              _UploadParams(
                title: title,
                allCells: _allCells,
                selectedCellIds: _selectedIds.toList(),
                cellTypeId: _allCells ? null : _selectedCellTypeId,
              ),
            );
          },
          child: const Text('Enviar'),
        ),
      ],
    );
  }
}

// ── Material Card ────────────────────────────────────────────────────────────

class _AdminMaterialCard extends StatelessWidget {
  const _AdminMaterialCard({
    this.title,
    required this.subtitle,
    required this.typeIcon,
    required this.typeColor,
    required this.onView,
    required this.onDelete,
    required this.isOpening,
  });
  final String? title;
  final String subtitle;
  final IconData typeIcon;
  final Color typeColor;
  final bool isOpening;
  final VoidCallback onView;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: InkWell(
        onTap: null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSpacing.sm),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 22),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title ?? '', style: AppTypography.titleSmall),
                      const SizedBox(height: AppSpacing.xs2),
                      Text(
                        subtitle,
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.error,
                    size: 20,
                  ),
                  tooltip: 'Excluir',
                  onPressed: onDelete,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: isOpening ? 'Abrindo...' : 'Visualizar / Baixar',
              variant: AppButtonVariant.outline,
              size: AppButtonSize.sm,
              prefixIcon: isOpening ? null : Icons.open_in_new_outlined,
              onPressed: isOpening ? null : onView,
            ),
          ],
        ),
      ),
    );
  }
}
