import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';

import '../../../../design_system/design_system.dart';
import '../../../../injection/injection.dart';
import '../../data/kids_repository.dart';
import '../widgets/kids_widgets.dart';

/// Cadastro rápido no balcão: criança nova cujo responsável não usa o app.
///
/// A meta é menos de um minuto — por isso só o nome e um responsável com
/// telefone são obrigatórios. Os campos de saúde ficam recolhidos: importam
/// muito quando existem, e atrapalham a fila quando não.
class KidsQuickRegisterPage extends StatefulWidget {
  const KidsQuickRegisterPage({super.key});

  @override
  State<KidsQuickRegisterPage> createState() => _KidsQuickRegisterPageState();
}

class _KidsQuickRegisterPageState extends State<KidsQuickRegisterPage> {
  late final KidsRepository _repo;
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _guardianNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _medicationsCtrl = TextEditingController();
  final _disabilitiesCtrl = TextEditingController();
  final _pickupCtrl = TextEditingController();
  final _birthDateCtrl = TextEditingController();

  final _phoneMask = MaskTextInputFormatter(
    mask: '(##) #####-####',
    filter: {'#': RegExp(r'\d')},
  );

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
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 5, now.month, now.day),
      firstDate: DateTime(now.year - 18),
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
      final child = await _repo.quickRegister(
        name: _nameCtrl.text.trim(),
        birthDate: _birthDate,
        gender: _gender,
        allergies: _allergiesCtrl.text.trim(),
        medications: _medicationsCtrl.text.trim(),
        disabilities: _disabilitiesCtrl.text.trim(),
        authorizedPickup: _pickupCtrl.text.trim(),
        guardians: [
          {
            'name': _guardianNameCtrl.text.trim(),
            // E.164: o WhatsApp e a ligação precisam do número sem máscara.
            'phone': '+55${_phoneCtrl.text.replaceAll(RegExp(r'\D'), '')}',
            'hasWhatsapp': _hasWhatsapp,
            'relation': _relation,
            'isPrimary': true,
            'canPickup': true,
          },
        ],
      );
      if (!mounted) return;
      Navigator.of(context).pop(child);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showKidsError(context, kidsErrorMessage(e, 'Não foi possível cadastrar'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(title: const Text('Cadastro rápido')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
          children: [
            AppSectionHeader(title: 'Criança'),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _nameCtrl,
              label: 'Nome completo',
              autofocus: true,
              validator: (v) =>
                  (v ?? '').trim().isEmpty ? 'Informe o nome da criança' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _birthDateCtrl,
                    label: 'Nascimento',
                    readOnly: true,
                    hint: 'Toque para escolher',
                    prefixIcon: Icons.cake_outlined,
                    onTap: _pickBirthDate,
                    onSuffixTap: _pickBirthDate,
                    suffixIcon: Icons.calendar_month_outlined,
                  ),
                ),
              ],
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

            const SizedBox(height: AppSpacing.base),
            AppSectionHeader(title: 'Responsável'),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _guardianNameCtrl,
              label: 'Nome do responsável',
              validator: (v) => (v ?? '').trim().isEmpty
                  ? 'Informe quem está entregando'
                  : null,
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
                    onSelected: (_) => setState(() => _relation = option.$1),
                  ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _hasWhatsapp,
              onChanged: (v) => setState(() => _hasWhatsapp = v),
              title: const Text('Tem WhatsApp neste número'),
              subtitle: const Text(
                'É por onde o aviso chega se não houver app',
              ),
            ),

            const SizedBox(height: AppSpacing.base),
            // Saúde é dado sensível: só é coletado se houver algo a informar,
            // e a tela diz isso em voz alta.
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
                    style: AppTypography.bodySmall.copyWith(color: mutedColor),
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
              label: 'Cadastrar e fazer check-in',
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
            const SizedBox(height: AppSpacing.xl2),
          ],
        ),
      ),
    );
  }
}
