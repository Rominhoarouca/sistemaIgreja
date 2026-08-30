import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../design_system/design_system.dart';
import '../../../../injection/injection.dart';
import '../../data/kids_models.dart';
import '../../data/kids_repository.dart';
import '../widgets/kids_widgets.dart';
import '../../../../shared/utils/phone_input.dart';

/// Cadastro/edição do próprio filho pelo responsável.
///
/// Sem [existing] é cadastro novo — pede também o telefone do responsável
/// (o backend vincula à conta logada). Com [existing] é edição — só os
/// dados da criança mudam, os responsáveis já cadastrados não são tocados
/// aqui.
class GuardianChildFormPage extends StatefulWidget {
  const GuardianChildFormPage({super.key, this.existing});

  final KidsChild? existing;

  bool get isEditing => existing != null;

  @override
  State<GuardianChildFormPage> createState() => _GuardianChildFormPageState();
}

class _GuardianChildFormPageState extends State<GuardianChildFormPage> {
  late final KidsRepository _repo;
  final _formKey = GlobalKey<FormState>();

  late final _nameCtrl = TextEditingController(text: widget.existing?.name);
  final _guardianNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  late final _allergiesCtrl = TextEditingController(
    text: widget.existing?.health.allergies,
  );
  late final _medicationsCtrl = TextEditingController(
    text: widget.existing?.health.medications,
  );
  late final _disabilitiesCtrl = TextEditingController(
    text: widget.existing?.health.disabilities,
  );
  late final _pickupCtrl = TextEditingController(
    text: widget.existing?.authorizedPickup,
  );
  final _birthDateCtrl = TextEditingController();

  /// Formatter compartilhado — aceita fixo (10 dígitos) e celular (11).
  final _phoneMask = const BrPhoneInputFormatter();

  DateTime? _birthDate;
  String? _gender;
  String _relation = 'MAE';
  bool _hasWhatsapp = true;
  bool _showHealth = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _repo = KidsRepository(getIt<Dio>());
    _birthDate = widget.existing?.birthDate;
    if (_birthDate != null) _birthDateCtrl.text = formatDate(_birthDate!);
    _gender = widget.existing?.gender;
    _showHealth = !(widget.existing?.health.isEmpty ?? true);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _guardianNameCtrl.dispose();
    _phoneCtrl.dispose();
    _allergiesCtrl.dispose();
    _medicationsCtrl.dispose();
    _disabilitiesCtrl.dispose();
    _pickupCtrl.dispose();
    _birthDateCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    var first = DateTime(now.year - 18);
    // Uma data já salva fora da faixa (erro de digitação no balcão, por
    // exemplo) faria o showDatePicker estourar o assert `initialDate >=
    // firstDate`. Aqui a faixa cede para caber o que já existe.
    final initial = _birthDate ?? DateTime(now.year - 5, now.month, now.day);
    if (initial.isBefore(first)) first = initial;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isAfter(now) ? now : initial,
      firstDate: first,
      lastDate: now,
      helpText: 'Data de nascimento',
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthDateCtrl.text = formatDate(picked);
      });
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    try {
      final KidsChild child;
      if (widget.isEditing) {
        child = await _repo.updateChild(
          widget.existing!.id,
          name: _nameCtrl.text.trim(),
          birthDate: _birthDate,
          gender: _gender,
          allergies: _allergiesCtrl.text.trim(),
          medications: _medicationsCtrl.text.trim(),
          disabilities: _disabilitiesCtrl.text.trim(),
          authorizedPickup: _pickupCtrl.text.trim(),
        );
      } else {
        child = await _repo.createOwnChild(
          name: _nameCtrl.text.trim(),
          birthDate: _birthDate,
          gender: _gender,
          allergies: _allergiesCtrl.text.trim(),
          medications: _medicationsCtrl.text.trim(),
          disabilities: _disabilitiesCtrl.text.trim(),
          authorizedPickup: _pickupCtrl.text.trim(),
          guardianName: _guardianNameCtrl.text.trim(),
          // E.164: o WhatsApp e a ligação precisam do número sem máscara.
          guardianPhone: '+55${_phoneCtrl.text.replaceAll(RegExp(r'\D'), '')}',
          guardianHasWhatsapp: _hasWhatsapp,
          guardianRelation: _relation,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(child);
    } catch (e) {
      // Captura tudo, não só DioException: um erro de parse deixaria o botão
      // preso em "carregando" para sempre, sem mensagem nenhuma.
      if (!mounted) return;
      setState(() => _saving = false);
      showKidsError(context, kidsErrorMessage(e, 'Não foi possível salvar'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Editar filho' : 'Adicionar filho'),
      ),
      body: AppContentWidth(
        maxWidth: AppBreakpoints.formMaxWidth + 160,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
            children: [
              AppSectionHeader(title: 'Criança'),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _nameCtrl,
                label: 'Nome completo',
                autofocus: !widget.isEditing,
                validator: (v) => (v ?? '').trim().isEmpty
                    ? 'Informe o nome da criança'
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              // A data escolhida vai no controller, não no `hint`: como hint ela
              // era pintada em cinza de placeholder e parecia campo vazio.
              AppTextField(
                controller: _birthDateCtrl,
                label: 'Nascimento',
                readOnly: true,
                hint: 'Toque para escolher',
                prefixIcon: Icons.cake_outlined,
                onTap: _pickBirthDate,
                onSuffixTap: _pickBirthDate,
                suffixIcon: Icons.calendar_month_outlined,
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final option in const [
                    ('MASCULINO', 'Menino'),
                    ('FEMININO', 'Menina'),
                  ])
                    ChoiceChip(
                      label: Text(option.$2),
                      selected: _gender == option.$1,
                      onSelected: (selected) =>
                          setState(() => _gender = selected ? option.$1 : null),
                    ),
                ],
              ),

              if (!widget.isEditing) ...[
                const SizedBox(height: AppSpacing.base),
                AppSectionHeader(title: 'Seu contato'),
                const SizedBox(height: AppSpacing.sm),
                AppTextField(
                  controller: _guardianNameCtrl,
                  label: 'Seu nome',
                  validator: (v) =>
                      (v ?? '').trim().isEmpty ? 'Informe seu nome' : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _phoneCtrl,
                  label: 'Telefone',
                  hint: '(11) 99999-9999',
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    _phoneMask,
                    LengthLimitingTextInputFormatter(15),
                  ],
                  validator: (v) {
                    final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
                    return digits.length < 10 ? 'Telefone incompleto' : null;
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final option in const [
                      ('MAE', 'Mãe'),
                      ('PAI', 'Pai'),
                      ('AVO', 'Avô/avó'),
                      ('TIO', 'Tio/tia'),
                      ('RESPONSAVEL_LEGAL', 'Responsável'),
                    ])
                      ChoiceChip(
                        label: Text(option.$2),
                        selected: _relation == option.$1,
                        onSelected: (_) =>
                            setState(() => _relation = option.$1),
                      ),
                  ],
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _hasWhatsapp,
                  onChanged: (v) => setState(() => _hasWhatsapp = v),
                  title: const Text('Tenho WhatsApp neste número'),
                  subtitle: const Text(
                    'É por onde o aviso chega se você não abrir o app',
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.base),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Cuidados especiais',
                            style: AppTypography.titleSmall,
                          ),
                        ),
                        Switch(
                          value: _showHealth,
                          onChanged: (v) => setState(() => _showHealth = v),
                        ),
                      ],
                    ),
                    Text(
                      'Informe apenas o necessário para o cuidado durante a aula.',
                      style: AppTypography.bodySmall.copyWith(
                        color: mutedColor,
                      ),
                    ),
                    if (_showHealth) ...[
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _allergiesCtrl,
                        label: 'Alergias',
                        hint: 'Amendoim, lactose...',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _medicationsCtrl,
                        label: 'Medicação em uso',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: _disabilitiesCtrl,
                        label: 'Deficiência',
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _pickupCtrl,
                label: 'Quem mais pode retirar (opcional)',
                hint: 'Nome de outra pessoa autorizada',
              ),

              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: widget.isEditing
                    ? 'Salvar alterações'
                    : 'Cadastrar filho',
                isLoading: _saving,
                onPressed: _saving ? null : _save,
              ),
              const SizedBox(height: AppSpacing.xl2),
            ],
          ),
        ),
      ),
    );
  }
}
