import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../design_system/design_system.dart';
import '../utils/snackbar_helper.dart';
import '../../../../shared/widgets/cep_address_fields.dart';
import '../widgets/demographic_fields.dart';

/// SRP: responsável apenas pelo formulário de novo visitante.
class NewVisitorSheet extends StatefulWidget {
  const NewVisitorSheet({super.key, required this.dio, this.cellId});
  final Dio dio;

  /// Quando aberto a partir de uma célula, já vincula o visitante a ela.
  final String? cellId;

  @override
  State<NewVisitorSheet> createState() => _NewVisitorSheetState();
}

class _NewVisitorSheetState extends State<NewVisitorSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  CepAddressValue _addressValue = const CepAddressValue(
    address: '',
    numero: '',
    complemento: null,
    bairroId: null,
  );
  String? _gender;
  DateTime? _birthDate;
  String? _maritalStatus;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    if (name.isEmpty || phone.isEmpty) {
      showDashboardSnackBar(
        context,
        'Nome e telefone são obrigatórios',
        backgroundColor: AppColors.warning,
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.dio.post(
        '/visitors',
        data: {
          'name': name,
          'phone': phone,
          if (_emailCtrl.text.trim().isNotEmpty)
            'email': _emailCtrl.text.trim(),
          if (_addressValue.address.isNotEmpty)
            'address': _addressValue.address,
          if (_addressValue.numero.isNotEmpty) 'numero': _addressValue.numero,
          if (_addressValue.complemento != null)
            'complemento': _addressValue.complemento,
          if (_addressValue.bairroId != null)
            'bairroId': _addressValue.bairroId,
          if (_gender != null) 'gender': _gender,
          if (_birthDate != null) 'birthDate': apiBirthDate(_birthDate),
          if (_maritalStatus != null) 'maritalStatus': _maritalStatus,
          if (widget.cellId != null) 'cellId': widget.cellId,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showDashboardSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao cadastrar visitante',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              Text('Novo Visitante', style: AppTypography.headlineSmall),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                controller: _nameCtrl,
                label: 'Nome *',
                hint: 'Nome completo',
                prefixIcon: Icons.person_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _phoneCtrl,
                label: 'Telefone *',
                hint: '(11) 99999-9999',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _emailCtrl,
                label: 'E-mail',
                hint: 'email@exemplo.com',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              CepAddressFields(
                dio: widget.dio,
                onChanged: (v) => setState(() => _addressValue = v),
              ),
              const SizedBox(height: AppSpacing.base),
              DemographicFields(
                gender: _gender,
                birthDate: _birthDate,
                maritalStatus: _maritalStatus,
                onGenderChanged: (v) => setState(() => _gender = v),
                onBirthDateChanged: (v) => setState(() => _birthDate = v),
                onMaritalStatusChanged: (v) =>
                    setState(() => _maritalStatus = v),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: _isSaving ? 'Salvando...' : 'Cadastrar Visitante',
                prefixIcon: Icons.person_add_outlined,
                onPressed: _isSaving ? null : _save,
              ),
              const SizedBox(height: AppSpacing.base),
            ],
          ),
        ),
      ),
    );
  }
}
