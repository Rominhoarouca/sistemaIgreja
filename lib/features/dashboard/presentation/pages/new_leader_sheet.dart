import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../design_system/design_system.dart';
import '../utils/snackbar_helper.dart';
import '../../../../shared/utils/phone_input.dart';

/// SRP: responsável apenas pelo formulário de novo líder.
class NewLeaderSheet extends StatefulWidget {
  const NewLeaderSheet({super.key, required this.dio});
  final Dio dio;

  @override
  State<NewLeaderSheet> createState() => _NewLeaderSheetState();
}

class _NewLeaderSheetState extends State<NewLeaderSheet> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (name.isEmpty || email.isEmpty || password.length < 6) {
      showDashboardSnackBar(
        context,
        'Preencha nome, email e senha (mínimo 6 caracteres)',
        backgroundColor: AppColors.warning,
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.dio.post(
        '/auth/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'role': 'LIDER',
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      showDashboardSnackBar(
        context,
        'Líder cadastrado com sucesso',
        backgroundColor: AppColors.success,
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showDashboardSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao cadastrar líder',
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
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Voltar',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: AppSpacing.minTouchTarget,
                      minHeight: AppSpacing.minTouchTarget,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Novo Líder',
                      style: AppTypography.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                controller: _nameCtrl,
                label: 'Nome completo',
                hint: 'Nome do líder',
                prefixIcon: Icons.person_outline,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _emailCtrl,
                label: 'E-mail',
                hint: 'lider@email.com',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _phoneCtrl,
                label: 'Telefone',
                hint: '(11) 99999-9999',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                inputFormatters: brPhoneInputFormatters,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _passwordCtrl,
                label: 'Senha temporária *',
                hint: 'Mínimo 6 caracteres',
                prefixIcon: Icons.lock_outline,
                obscureText: true,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: _isSaving ? 'Salvando...' : 'Criar Líder',
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
