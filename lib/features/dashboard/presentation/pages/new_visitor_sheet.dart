import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../design_system/design_system.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/demographic_fields.dart';

/// SRP: responsável apenas pelo formulário de novo visitante.
class NewVisitorSheet extends StatefulWidget {
  const NewVisitorSheet({super.key, required this.dio});
  final Dio dio;

  @override
  State<NewVisitorSheet> createState() => _NewVisitorSheetState();
}

class _NewVisitorSheetState extends State<NewVisitorSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  String? _gender;
  DateTime? _birthDate;
  String? _maritalStatus;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _cityCtrl.dispose();
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
          if (_addressCtrl.text.trim().isNotEmpty)
            'address': _addressCtrl.text.trim(),
          if (_neighborhoodCtrl.text.trim().isNotEmpty)
            'neighborhood': _neighborhoodCtrl.text.trim(),
          if (_cityCtrl.text.trim().isNotEmpty) 'city': _cityCtrl.text.trim(),
          if (_gender != null) 'gender': _gender,
          if (_birthDate != null) 'birthDate': apiBirthDate(_birthDate),
          if (_maritalStatus != null) 'maritalStatus': _maritalStatus,
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
              AppTextField(
                controller: _addressCtrl,
                label: 'Endereço',
                hint: 'Rua, número',
                prefixIcon: Icons.location_on_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _neighborhoodCtrl,
                label: 'Bairro',
                hint: 'Bairro',
                prefixIcon: Icons.map_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _cityCtrl,
                label: 'Cidade',
                hint: 'São Paulo',
                prefixIcon: Icons.location_city_outlined,
                textInputAction: TextInputAction.done,
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
