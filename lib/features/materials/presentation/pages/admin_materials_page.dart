import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/auth_storage.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';

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

// ── State ───────────────────────────────────────────────────────────────────

class _AdminMaterialsPageState extends State<AdminMaterialsPage> {
  final _searchCtrl = TextEditingController();
  late final Dio _dio;

  String _query = '';
  bool _isLoading = true;
  bool _isUploading = false;
  String? _error;
  List<_MaterialData> _materials = [];
  List<_CellOption> _cells = [];
  final Map<String, bool> _opening = {};

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
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _dio.get('/materials'),
        _dio.get('/cells'),
      ]);
      final mData =
          (results[0].data as Map<String, dynamic>)['materials'] as List;
      final cData = (results[1].data as Map<String, dynamic>)['cells'] as List;
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
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar materiais';
        _isLoading = false;
      });
    }
  }

  List<_MaterialData> get _filtered {
    final q = _query.toLowerCase();
    if (q.isEmpty) return _materials;
    return _materials.where((m) => m.title.toLowerCase().contains(q)).toList();
  }

  // ── Upload ────────────────────────────────────────────────────────────────

  Future<void> _uploadMaterial() async {
    if (_cells.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nenhuma célula cadastrada para associar material'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'mp4', 'mov'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;

    if (!mounted) return;
    final params = await showDialog<_UploadParams>(
      context: context,
      builder: (ctx) => _UploadDialog(
        defaultTitle: file.name.replaceAll(RegExp(r'\.\w+$'), ''),
        cells: _cells,
      ),
    );
    if (params == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = file.bytes;
      if (bytes == null) throw Exception('Não foi possível ler o arquivo');
      final formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(bytes, filename: file.name),
        'title': params.title,
        'cellId': params.cellId,
      });
      await _dio.post('/materials', data: formData);
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"${params.title}" enviado com sucesso!'),
          backgroundColor: AppColors.success,
        ),
      );
      _loadData();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?['message'] as String? ??
                'Erro ao enviar arquivo',
          ),
          backgroundColor: AppColors.error,
        ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Material excluído'),
          backgroundColor: AppColors.success,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?['message'] as String? ??
                'Erro ao excluir material',
          ),
          backgroundColor: AppColors.error,
        ),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?['message'] as String? ??
                'Erro ao obter URL do arquivo',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
      );
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
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
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
      backgroundColor: AppColors.background,
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
    final filtered = _filtered;
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
        if (filtered.isEmpty)
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
          ...filtered.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _AdminMaterialCard(
                material: m,
                typeIcon: _typeIcon(m.type),
                typeColor: _typeColor(m.type),
                isOpening: _opening[m.id] == true,
                onView: () => _viewMaterial(m),
                onDelete: () => _deleteMaterial(m),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Upload Dialog ────────────────────────────────────────────────────────────

class _UploadParams {
  final String title;
  final String cellId;
  const _UploadParams({required this.title, required this.cellId});
}

class _UploadDialog extends StatefulWidget {
  const _UploadDialog({required this.defaultTitle, required this.cells});
  final String defaultTitle;
  final List<_CellOption> cells;

  @override
  State<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<_UploadDialog> {
  late final TextEditingController _titleCtrl;
  late String _selectedCellId;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.defaultTitle);
    _selectedCellId = widget.cells.first.id;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
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
          DropdownButtonFormField<String>(
            value: _selectedCellId,
            decoration: const InputDecoration(
              labelText: 'Célula',
              border: OutlineInputBorder(),
            ),
            items: widget.cells
                .map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Text(c.name, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _selectedCellId = v!),
          ),
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
            Navigator.pop(
              context,
              _UploadParams(title: title, cellId: _selectedCellId),
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
    required this.material,
    required this.typeIcon,
    required this.typeColor,
    required this.onView,
    required this.onDelete,
    required this.isOpening,
  });

  final _MaterialData material;
  final IconData typeIcon;
  final Color typeColor;
  final bool isOpening;
  final VoidCallback onView;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
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
                    Text(material.title, style: AppTypography.titleSmall),
                    const SizedBox(height: AppSpacing.xs2),
                    Text(
                      '${material.type.toUpperCase()} · ${material.formattedSize}',
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
    );
  }
}
