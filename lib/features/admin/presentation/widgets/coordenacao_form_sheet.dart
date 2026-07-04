import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/app_snackbar.dart';

// Preset colors for coordinations
const List<String> presetColors = [
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
  '#ffffff', // White
];

class CoordenacaoFormSheet extends StatefulWidget {
  const CoordenacaoFormSheet({
    required this.dio,
    required this.onSaved,
    this.editing,
  });

  final Dio dio;
  final VoidCallback onSaved;
  final Map<String, dynamic>? editing;

  @override
  State<CoordenacaoFormSheet> createState() => _CoordenacaoFormSheetState();
}

class _CoordenacaoFormSheetState extends State<CoordenacaoFormSheet> {
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
    _nameCtrl.text = widget.editing?['name'] as String? ?? '';
    _selectedColor = widget.editing?['color'] as String? ?? presetColors.first;
    if (!_isEditing) {
      _loadCoordenadores();
    }
  }

  Future<void> _loadCoordenadores() async {
    setState(() => _loadingCoordenadores = true);
    try {
      final resp = await widget.dio.get('/users/coordinadores');
      final users = ((resp.data as Map<String, dynamic>)['supervisors'] as List)
          .cast<Map<String, dynamic>>();

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
          '/coordenacoes/${widget.editing!['id']}',
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
      AppSnackbar.error(
        extractDioErrorMessage(e, fallback: 'Erro ao salvar coordenação'),
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
            children: presetColors.map((hex) {
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
