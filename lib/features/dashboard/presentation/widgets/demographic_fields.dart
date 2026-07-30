import 'package:flutter/material.dart';
import '../../../../design_system/design_system.dart';

/// Valor enviado à API × rótulo exibido. Não selecionar nada é válido: vira
/// "Não informado" nos relatórios demográficos. O gênero nunca é inferido a
/// partir do nome da pessoa.
const kGenderOptions = <String, String>{
  'MASCULINO': 'Masculino',
  'FEMININO': 'Feminino',
};

/// Mesmos rótulos do auto-cadastro do visitante, para que as duas origens
/// caiam nos mesmos grupos do relatório.
const kMaritalOptions = <String>[
  'Solteiro(a)',
  'Casado(a)',
  'Divorciado(a)',
  'Viúvo(a)',
  'União estável',
];

/// Formata a data no formato aceito pela API (`YYYY-MM-DD`).
String? apiBirthDate(DateTime? date) {
  if (date == null) return null;
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

/// Campos demográficos (gênero, nascimento, estado civil) compartilhados pelos
/// formulários de visitante e de membro de célula — são a fonte dos dados da
/// seção "Informações demográficas" do painel do administrador.
class DemographicFields extends StatelessWidget {
  const DemographicFields({
    super.key,
    required this.gender,
    required this.birthDate,
    required this.maritalStatus,
    required this.onGenderChanged,
    required this.onBirthDateChanged,
    required this.onMaritalStatusChanged,
  });

  final String? gender;
  final DateTime? birthDate;
  final String? maritalStatus;
  final ValueChanged<String?> onGenderChanged;
  final ValueChanged<DateTime?> onBirthDateChanged;
  final ValueChanged<String?> onMaritalStatusChanged;

  Future<void> _pickBirthDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 110),
      lastDate: now,
      helpText: 'Data de nascimento',
      cancelText: 'Cancelar',
      confirmText: 'Confirmar',
    );
    if (picked != null) onBirthDateChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FieldLabel('Gênero'),
        DropdownButtonFormField<String>(
          initialValue: gender,
          isExpanded: true,
          decoration: const InputDecoration(
            hintText: 'Não informado',
            prefixIcon: Icon(Icons.wc_outlined, size: AppSpacing.iconSm),
          ),
          items: [
            for (final entry in kGenderOptions.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: onGenderChanged,
        ),
        const SizedBox(height: AppSpacing.base),
        _FieldLabel('Data de nascimento'),
        InkWell(
          onTap: () => _pickBirthDate(context),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: InputDecorator(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.cake_outlined, size: AppSpacing.iconSm),
            ),
            isEmpty: birthDate == null,
            child: Text(
              birthDate == null ? '' : _formatBr(birthDate!),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        _FieldLabel('Estado civil'),
        DropdownButtonFormField<String>(
          initialValue: maritalStatus,
          isExpanded: true,
          decoration: const InputDecoration(
            hintText: 'Não informado',
            prefixIcon: Icon(
              Icons.favorite_outline,
              size: AppSpacing.iconSm,
            ),
          ),
          items: [
            for (final option in kMaritalOptions)
              DropdownMenuItem(value: option, child: Text(option)),
          ],
          onChanged: onMaritalStatusChanged,
        ),
      ],
    );
  }

  static String _formatBr(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}

/// Replica o rótulo acima do campo usado por [AppTextField].
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
