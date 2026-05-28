import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../design_system/design_system.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data helpers
// ─────────────────────────────────────────────────────────────────────────────

class _CellOption {
  _CellOption({required this.id, required this.name, required this.leaderName});

  final String id;
  final String name;
  final String leaderName;

  String get display => '$name (Líder: $leaderName)';
}

const _maritalOptions = [
  'Solteiro(a)',
  'Casado(a)',
  'Divorciado(a)',
  'Viúvo(a)',
  'União estável',
];

const _interestOptions = [
  'Membro da igreja',
  'Procurando batismo',
  'Quero ter uma célula em casa',
  'Preciso de oração',
];

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

/// Public visitor self-registration page — no login required.
class VisitorSelfRegisterPage extends StatefulWidget {
  const VisitorSelfRegisterPage({super.key});

  @override
  State<VisitorSelfRegisterPage> createState() =>
      _VisitorSelfRegisterPageState();
}

class _VisitorSelfRegisterPageState extends State<VisitorSelfRegisterPage> {
  // ── Dio (no auth) ──────────────────────────────────────────────────────────
  late final Dio _dio;

  // ── Form ───────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _customCellCtrl = TextEditingController();
  final _knownPersonCtrl = TextEditingController();

  DateTime? _birthDate;
  String? _maritalStatus;
  bool _isBaptized = false;
  bool _attendsCell = false;
  String? _selectedCellId; // null when "other"
  bool _customCellSelected = false;
  final Set<String> _interests = {};

  // ── Cell list state ────────────────────────────────────────────────────────
  bool _cellsLoading = true;
  List<_CellOption> _cells = [];

  // ── Submit state ───────────────────────────────────────────────────────────
  bool _submitting = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _loadCells();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _cityCtrl.dispose();
    _customCellCtrl.dispose();
    _knownPersonCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCells() async {
    try {
      final resp = await _dio.get('/cells/public');
      final list = ((resp.data as Map<String, dynamic>)['cells'] as List)
          .cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _cells = list
            .map(
              (c) => _CellOption(
                id: c['id'] as String,
                name: c['name'] as String? ?? '',
                leaderName: c['leaderName'] as String? ?? 'Sem líder',
              ),
            )
            .toList();
        _cellsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cellsLoading = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      helpText: 'Data de Nascimento',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Extra validation: cell selection when attends
    if (_attendsCell && !_customCellSelected && _selectedCellId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione a célula que você frequenta.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_attendsCell &&
        _customCellSelected &&
        _customCellCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o nome da célula.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final body = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'neighborhood': _neighborhoodCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'isBaptized': _isBaptized,
        'interests': _interests.toList(),
        if (_birthDate != null) 'birthDate': _birthDate!.toIso8601String(),
        if (_maritalStatus != null) 'maritalStatus': _maritalStatus,
        if (_knownPersonCtrl.text.trim().isNotEmpty)
          'knownPersonName': _knownPersonCtrl.text.trim(),
        if (_attendsCell && !_customCellSelected && _selectedCellId != null)
          'cellId': _selectedCellId,
        if (_attendsCell &&
            _customCellSelected &&
            _customCellCtrl.text.trim().isNotEmpty)
          'customCellName': _customCellCtrl.text.trim(),
      };

      await _dio.post('/visitors/self-register', data: body);
      if (!mounted) return;
      setState(() => _success = true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final msg =
          e.response?.data?['error']?['message'] as String? ??
          'Erro ao enviar cadastro. Tente novamente.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_success) return _SuccessScreen();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Header ────────────────────────────────────────────────────
          AppGradientHeader(
            height: 190,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePaddingH,
                  vertical: AppSpacing.md,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bem-vindo!',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Preencha seus dados para se cadastrar\nna nossa comunidade.',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Form ──────────────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePaddingH,
                vertical: AppSpacing.pagePaddingV,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('Dados Pessoais', Icons.person_outline),
                    const SizedBox(height: AppSpacing.base),

                    // Nome
                    AppTextField(
                      controller: _nameCtrl,
                      label: 'Nome completo *',
                      hint: 'Ex: João da Silva',
                      prefixIcon: Icons.person_outline,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Campo obrigatório'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.base),

                    // Telefone
                    AppTextField(
                      controller: _phoneCtrl,
                      label: 'Telefone / WhatsApp *',
                      hint: '(00) 00000-0000',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().length < 8)
                          ? 'Informe um telefone válido'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.base),

                    // Data de Nascimento
                    _DatePickerField(
                      label: 'Data de Nascimento *',
                      value: _birthDate,
                      onTap: _pickBirthDate,
                      validator: () =>
                          _birthDate == null ? 'Campo obrigatório' : null,
                    ),
                    const SizedBox(height: AppSpacing.base),

                    // Estado Civil (opcional)
                    _DropdownField<String>(
                      label: 'Estado Civil (opcional)',
                      value: _maritalStatus,
                      hint: 'Selecione',
                      items: _maritalOptions,
                      itemLabel: (v) => v,
                      onChanged: (v) => setState(() => _maritalStatus = v),
                    ),

                    _divider(),
                    _sectionHeader('Endereço', Icons.location_on_outlined),
                    const SizedBox(height: AppSpacing.base),

                    // Endereço
                    AppTextField(
                      controller: _addressCtrl,
                      label: 'Endereço *',
                      hint: 'Rua, número',
                      prefixIcon: Icons.home_outlined,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Campo obrigatório'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.base),

                    Row(
                      children: [
                        Expanded(
                          child: AppTextField(
                            controller: _neighborhoodCtrl,
                            label: 'Bairro *',
                            hint: 'Seu bairro',
                            textInputAction: TextInputAction.next,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Obrigatório'
                                : null,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: AppTextField(
                            controller: _cityCtrl,
                            label: 'Cidade *',
                            hint: 'Sua cidade',
                            textInputAction: TextInputAction.next,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Obrigatório'
                                : null,
                          ),
                        ),
                      ],
                    ),

                    _divider(),
                    _sectionHeader('Sobre Você', Icons.info_outline),
                    const SizedBox(height: AppSpacing.base),

                    // É batizado?
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.water_outlined,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const Expanded(
                            child: Text(
                              'Já é batizado(a)?',
                              style: AppTypography.bodyMedium,
                            ),
                          ),
                          Switch(
                            value: _isBaptized,
                            onChanged: (v) => setState(() => _isBaptized = v),
                            activeColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.base),

                    // Frequenta célula?
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.home_outlined,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          const Expanded(
                            child: Text(
                              'Frequenta alguma célula?',
                              style: AppTypography.bodyMedium,
                            ),
                          ),
                          Switch(
                            value: _attendsCell,
                            onChanged: (v) => setState(() {
                              _attendsCell = v;
                              if (!v) {
                                _selectedCellId = null;
                                _customCellSelected = false;
                                _customCellCtrl.clear();
                              }
                            }),
                            activeColor: AppColors.primary,
                          ),
                        ],
                      ),
                    ),

                    if (_attendsCell) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _CellSelector(
                        cells: _cells,
                        loading: _cellsLoading,
                        selectedCellId: _selectedCellId,
                        customCellSelected: _customCellSelected,
                        customCellCtrl: _customCellCtrl,
                        onCellSelected: (id, isCustom) => setState(() {
                          _selectedCellId = isCustom ? null : id;
                          _customCellSelected = isCustom;
                          if (!isCustom) _customCellCtrl.clear();
                        }),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.base),

                    // Conhece alguém?
                    AppTextField(
                      controller: _knownPersonCtrl,
                      label: 'Conhece alguém na igreja? (opcional)',
                      hint: 'Nome da pessoa',
                      prefixIcon: Icons.people_outline,
                      textInputAction: TextInputAction.next,
                    ),

                    _divider(),
                    _sectionHeader(
                      'Como posso ajudar você?',
                      Icons.favorite_outline,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Selecione todas as opções que se aplicam',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: _interestOptions
                          .map(
                            (opt) => FilterChip(
                              label: Text(opt),
                              selected: _interests.contains(opt),
                              onSelected: (selected) => setState(() {
                                if (selected) {
                                  _interests.add(opt);
                                } else {
                                  _interests.remove(opt);
                                }
                              }),
                              selectedColor: AppColors.primary.withValues(
                                alpha: 0.15,
                              ),
                              checkmarkColor: AppColors.primary,
                              labelStyle: AppTypography.bodySmall.copyWith(
                                color: _interests.contains(opt)
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                                fontWeight: _interests.contains(opt)
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          )
                          .toList(),
                    ),

                    const SizedBox(height: AppSpacing.xl2),

                    AppButton(
                      label: 'Enviar Cadastro',
                      isLoading: _submitting,
                      onPressed: _submit,
                      prefixIcon: Icons.send_outlined,
                    ),

                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Text(title, style: AppTypography.titleMedium),
      ],
    );
  }

  Widget _divider() => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.base),
    child: Divider(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Cell Selector widget
// ─────────────────────────────────────────────────────────────────────────────

class _CellSelector extends StatelessWidget {
  const _CellSelector({
    required this.cells,
    required this.loading,
    required this.selectedCellId,
    required this.customCellSelected,
    required this.customCellCtrl,
    required this.onCellSelected,
  });

  final List<_CellOption> cells;
  final bool loading;
  final String? selectedCellId;
  final bool customCellSelected;
  final TextEditingController customCellCtrl;
  final void Function(String? id, bool isCustom) onCellSelected;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.sm),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final String? currentValue = customCellSelected
        ? '__custom__'
        : selectedCellId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DropdownField<String>(
          label: 'Qual célula você frequenta? *',
          value: currentValue,
          hint: 'Selecione uma célula',
          items: [...cells.map((c) => c.id), '__custom__'],
          itemLabel: (v) {
            if (v == '__custom__') return 'Outra (não está na lista)';
            final cell = cells.firstWhere((c) => c.id == v);
            return cell.display;
          },
          onChanged: (v) {
            if (v == '__custom__') {
              onCellSelected(null, true);
            } else {
              onCellSelected(v, false);
            }
          },
        ),
        if (customCellSelected) ...[
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: customCellCtrl,
            label: 'Nome da célula *',
            hint: 'Digite o nome da célula',
            prefixIcon: Icons.edit_outlined,
            textInputAction: TextInputAction.next,
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.validator,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final String? Function() validator;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return FormField<DateTime>(
      initialValue: value,
      validator: (_) => validator(),
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onTap,
              child: AbsorbPointer(
                child: AppTextField(
                  controller: TextEditingController(
                    text: value != null ? fmt.format(value!) : '',
                  ),
                  label: label,
                  hint: 'DD/MM/AAAA',
                  prefixIcon: Icons.cake_outlined,
                  readOnly: true,
                ),
              ),
            ),
            if (field.errorText != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  field.errorText!,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final String hint;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: isDark ? AppColors.dividerDark : AppColors.divider,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              value: value,
              hint: Text(
                hint,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              items: items
                  .map(
                    (item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(
                        itemLabel(item),
                        style: AppTypography.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.base),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Success Screen
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessScreen extends StatelessWidget {
  const _SuccessScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.success,
                    size: 48,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Cadastro Enviado!',
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Obrigado por se cadastrar. Em breve alguém\nda nossa equipe entrará em contato.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl2),
                AppButton(
                  label: 'Fechar',
                  variant: AppButtonVariant.outline,
                  isFullWidth: false,
                  prefixIcon: Icons.close,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
