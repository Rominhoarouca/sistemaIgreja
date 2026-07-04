import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/auth_storage.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';

/// Shows a toast above any modal/sheet using the Overlay system.
void _showOverlayToast(
  BuildContext context,
  String message, {
  bool success = false,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _OverlayToast(
      message: message,
      success: success,
      onDismiss: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _OverlayToast extends StatefulWidget {
  const _OverlayToast({
    required this.message,
    required this.success,
    required this.onDismiss,
  });

  final String message;
  final bool success;
  final VoidCallback onDismiss;

  @override
  State<_OverlayToast> createState() => _OverlayToastState();
}

class _OverlayToastState extends State<_OverlayToast>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _opacity = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _ctrl.reverse().then((_) => widget.onDismiss());
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      left: 16,
      right: 16,
      child: FadeTransition(
        opacity: _opacity,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: widget.success ? AppColors.success : AppColors.error,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(
                  widget.success
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.message,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class _CoordenacaoInfo {
  _CoordenacaoInfo({
    required this.id,
    required this.name,
    required this.color,
    required this.coordinadorId,
    required this.coordinadorName,
    required this.supervisoresCount,
    required this.supervisores,
  });

  final String id;
  String name;
  String color;
  final String coordinadorId;
  final String coordinadorName;
  final int supervisoresCount;
  final List<Map<String, dynamic>> supervisores;

  Color get parsedColor {
    try {
      return Color(int.parse(color.replaceFirst('#', '0xFF')));
    } catch (_) {
      return Colors.blueGrey;
    }
  }

  factory _CoordenacaoInfo.fromJson(Map<String, dynamic> json) =>
      _CoordenacaoInfo(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        color: json['color'] as String? ?? '#607D8B',
        coordinadorId: json['coordinadorId'] as String? ?? '',
        coordinadorName: json['coordinadorName'] as String? ?? '',
        supervisoresCount: json['supervisoresCount'] as int? ?? 0,
        supervisores: (json['supervisores'] as List? ?? [])
            .cast<Map<String, dynamic>>(),
      );
}

// Preset colors for coordinations
const _presetColors = [
  '#3F51B5', // Indigo
  '#2196F3', // Blue
  '#009688', // Teal
  '#4CAF50', // Green
  '#8BC34A', // Light Green
  '#CDDC39', // Lime
  '#FF9800', // Orange
  '#FF5722', // Deep Orange
  '#E91E63', // Pink
  '#9C27B0', // Purple
  '#607D8B', // Blue Grey
  '#795548', // Brown
];

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class AdminCoordenacoes extends StatefulWidget {
  const AdminCoordenacoes({super.key});

  @override
  State<AdminCoordenacoes> createState() => _AdminCoordenacoes();
}

class _AdminCoordenacoes extends State<AdminCoordenacoes> {
  late final Dio _dio;
  bool _loading = true;
  String? _error;
  List<_CoordenacaoInfo> _coordenacoes = [];

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
      final response = await _dio.get('/coordenacoes');

      final coordList =
          ((response.data as Map<String, dynamic>)['coordenacoes'] as List)
              .cast<Map<String, dynamic>>();

      if (!mounted) return;
      setState(() {
        _coordenacoes = coordList.map(_CoordenacaoInfo.fromJson).toList();
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar coordenações';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        title: const Text('Coordenações'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Novo Coordenador',
            onPressed: () => _showCreateCoordinadorSheet(context),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Nova coordenação',
            onPressed: () => _showFormSheet(context, null),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loading ? null : _loadData,
          ),
        ],
      ),
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
          : _coordenacoes.isEmpty
          ? AppEmptyState(
              title: 'Nenhuma coordenação',
              subtitle: 'Toque em "+" para criar a primeira coordenação.',
              icon: Icons.account_tree_outlined,
              actionLabel: 'Nova Coordenação',
              action: () => _showFormSheet(context, null),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
                itemCount: _coordenacoes.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) => _CoordenacaoCard(
                  info: _coordenacoes[i],
                  onEdit: () => _showFormSheet(context, _coordenacoes[i]),
                  onDelete: () => _confirmDelete(context, _coordenacoes[i]),
                ),
              ),
            ),
    );
  }

  void _showCreateCoordinadorSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateCoordinadorSheet(dio: _dio, onCreated: _loadData),
    );
  }

  void _showFormSheet(BuildContext context, _CoordenacaoInfo? editing) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CoordenacaoFormSheet(
        editing: editing,
        dio: _dio,
        onSaved: _loadData,
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    _CoordenacaoInfo info,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir coordenação'),
        content: Text(
          'Deseja excluir "${info.name}"? Os supervisores vinculados serão desvinculados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _dio.delete('/coordenacoes/${info.id}');
      _loadData();
    } on DioException catch (e) {
      if (!mounted) return;
      _showOverlayToast(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao excluir coordenação',
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card
// ─────────────────────────────────────────────────────────────────────────────

class _CoordenacaoCard extends StatelessWidget {
  const _CoordenacaoCard({
    required this.info,
    required this.onEdit,
    required this.onDelete,
  });

  final _CoordenacaoInfo info;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: info.parsedColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppSpacing.sm),
            ),
            child: Icon(
              Icons.account_tree_outlined,
              color: info.parsedColor,
              size: 24,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        color: info.parsedColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: Text(info.name, style: AppTypography.titleSmall),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Coordenador: ${info.coordinadorName}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${info.supervisoresCount} supervisor${info.supervisoresCount != 1 ? 'es' : ''}',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert,
              color: AppColors.textSecondary,
              size: 20,
            ),
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', child: Text('Editar')),
              const PopupMenuItem(
                value: 'delete',
                child: Text(
                  'Excluir',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
            onSelected: (action) {
              if (action == 'edit') onEdit();
              if (action == 'delete') onDelete();
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Form Sheet (create / edit)
// ─────────────────────────────────────────────────────────────────────────────

class _CoordenacaoFormSheet extends StatefulWidget {
  const _CoordenacaoFormSheet({
    required this.editing,
    required this.dio,
    required this.onSaved,
  });

  final _CoordenacaoInfo? editing;
  final Dio dio;
  final VoidCallback onSaved;

  @override
  State<_CoordenacaoFormSheet> createState() => _CoordenacaoFormSheetState();
}

class _CoordenacaoFormSheetState extends State<_CoordenacaoFormSheet> {
  final _nameCtrl = TextEditingController();
  late String _selectedColor;
  String? _selectedCoordinadorId;
  List<Map<String, dynamic>> _coordenadores = [];
  bool _saving = false;
  bool _loadingCoordenadores = false;

  bool get _isEditing => widget.editing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.editing?.name ?? '';
    _selectedColor = widget.editing?.color ?? _presetColors.first;
    if (!_isEditing) {
      _loadCoordenadores();
    }
  }

  Future<void> _loadCoordenadores() async {
    setState(() => _loadingCoordenadores = true);
    try {
      // Use supervisors endpoint filtering by role COORDENADOR
      final resp = await widget.dio.get('/users/coordinadores');
      final users = ((resp.data as Map<String, dynamic>)['supervisors'] as List)
          .cast<Map<String, dynamic>>();

      // Filter for COORDENADOR role and not already assigned to a coordenação
      final disponibles = users
          .where((u) => (u['role'] as String?) == 'COORDENADOR')
          .toList();

      if (mounted) {
        setState(() {
          _coordenadores = disponibles;
          _loadingCoordenadores = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingCoordenadores = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao carregar coordenadores: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe um nome para a coordenação')),
      );
      return;
    }

    if (!_isEditing && _selectedCoordinadorId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecione um coordenador')));
      return;
    }

    setState(() => _saving = true);
    try {
      if (_isEditing) {
        await widget.dio.patch(
          '/coordenacoes/${widget.editing!.id}',
          data: {'name': name, 'color': _selectedColor},
        );
      } else {
        await widget.dio.post(
          '/coordenacoes',
          data: {
            'name': name,
            'color': _selectedColor,
            'coordinadorId': _selectedCoordinadorId,
          },
        );
      }
      if (!mounted) return;
      widget.onSaved();
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?['message'] as String? ??
                'Erro ao salvar coordenação',
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
          Text(
            _isEditing ? 'Editar Coordenação' : 'Nova Coordenação',
            style: AppTypography.titleMedium,
          ),
          const SizedBox(height: AppSpacing.base),
          AppTextField(
            controller: _nameCtrl,
            label: 'Nome da coordenação',
            hint: 'Ex.: Coordenação Norte',
          ),
          const SizedBox(height: AppSpacing.base),
          if (!_isEditing) ...[
            Text('Coordenador', style: AppTypography.labelMedium),
            const SizedBox(height: AppSpacing.xs),
            if (_loadingCoordenadores)
              const Padding(
                padding: EdgeInsets.all(AppSpacing.md),
                child: CircularProgressIndicator(),
              )
            else if (_coordenadores.isEmpty)
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Text(
                  'Nenhum coordenador disponível',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              DropdownButtonFormField<String>(
                initialValue: _selectedCoordinadorId,
                items: _coordenadores.map((coord) {
                  final id = coord['id'] as String;
                  final name = coord['name'] as String;
                  return DropdownMenuItem(value: id, child: Text(name));
                }).toList(),
                onChanged: (val) =>
                    setState(() => _selectedCoordinadorId = val),
                decoration: InputDecoration(
                  hintText: 'Selecione um coordenador',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.base),
          ],
          Text('Cor da coordenação', style: AppTypography.labelMedium),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: _presetColors.map((hex) {
              Color c;
              try {
                c = Color(int.parse(hex.replaceFirst('#', '0xFF')));
              } catch (_) {
                c = Colors.grey;
              }
              final selected = _selectedColor == hex;
              return GestureDetector(
                onTap: () => setState(() => _selectedColor = hex),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: selected
                        ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                        : null,
                  ),
                  child: selected
                      ? const Icon(Icons.check, color: Colors.white, size: 18)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: AppSpacing.base),
          AppButton(
            label: _isEditing ? 'Salvar alterações' : 'Criar',
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
// Create Coordenador Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CreateCoordinadorSheet extends StatefulWidget {
  const _CreateCoordinadorSheet({required this.dio, required this.onCreated});

  final Dio dio;
  final VoidCallback onCreated;

  @override
  State<_CreateCoordinadorSheet> createState() =>
      _CreateCoordinadorSheetState();
}

class _CreateCoordinadorSheetState extends State<_CreateCoordinadorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.dio.post(
        '/users/create',
        data: {
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'password': _passwordCtrl.text,
          'role': 'COORDENADOR',
        },
      );
      if (!mounted) return;
      widget.onCreated();
      Navigator.of(context).pop();
      widget.onCreated();
      Navigator.of(context).pop();
      _showOverlayToast(
        context,
        'Coordenador cadastrado com sucesso!',
        success: true,
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _showOverlayToast(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao cadastrar coordenador',
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
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            Text('Novo Coordenador', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Cadastre um usuário com cargo de Coordenador.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            AppTextField(
              controller: _nameCtrl,
              label: 'Nome completo',
              hint: 'Nome do coordenador',
              prefixIcon: Icons.person_outline,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Nome obrigatório'
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _emailCtrl,
              label: 'E-mail',
              hint: 'email@exemplo.com',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'E-mail obrigatório';
                if (!v.contains('@')) return 'E-mail inválido';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _passwordCtrl,
              label: 'Senha',
              hint: 'Mínimo 6 caracteres',
              prefixIcon: Icons.lock_outline,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              validator: (v) => (v == null || v.length < 6)
                  ? 'Senha mínimo 6 caracteres'
                  : null,
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 16,
                ),
                label: Text(
                  _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            AppButton(
              label: 'Cadastrar Coordenador',
              isLoading: _saving,
              onPressed: _save,
              prefixIcon: Icons.save_outlined,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
