import 'package:flutter/material.dart';
import '../../../../design_system/design_system.dart';

/// Visitor Registration page — RF01
/// Collects: name, phone, email (opt), address, neighborhood, city, visitDate (opt), originChurch (opt)
class VisitorRegisterPage extends StatefulWidget {
  const VisitorRegisterPage({super.key});

  @override
  State<VisitorRegisterPage> createState() => _VisitorRegisterPageState();
}

class _VisitorRegisterPageState extends State<VisitorRegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _neighborhoodCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _churchCtrl = TextEditingController();
  // ignore: prefer_final_fields
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _addressCtrl.dispose();
    _neighborhoodCtrl.dispose();
    _cityCtrl.dispose();
    _churchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // ── Gradient header ────────────────────────────────────────────
          AppGradientHeader(
            height: 200,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: AppSpacing.base),
                    Text(
                      'Bem-vindo!',
                      style: AppTypography.headlineMedium.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Preencha seus dados para encontrarmos\numa célula próxima a você.',
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
                    Text(
                      'Dados pessoais',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.base),

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

                    AppTextField(
                      controller: _phoneCtrl,
                      label: 'Telefone / WhatsApp *',
                      hint: '(00) 00000-0000',
                      prefixIcon: Icons.phone_outlined,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().length < 10)
                          ? 'Telefone inválido'
                          : null,
                    ),
                    const SizedBox(height: AppSpacing.base),

                    AppTextField(
                      controller: _emailCtrl,
                      label: 'E-mail (opcional)',
                      hint: 'seu@email.com',
                      prefixIcon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),

                    const SizedBox(height: AppSpacing.xl),
                    const Divider(),
                    const SizedBox(height: AppSpacing.base),

                    Text(
                      'Endereço',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.base),

                    AppTextField(
                      controller: _addressCtrl,
                      label: 'Endereço *',
                      hint: 'Rua, número',
                      prefixIcon: Icons.location_on_outlined,
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

                    const SizedBox(height: AppSpacing.xl),
                    const Divider(),
                    const SizedBox(height: AppSpacing.base),

                    Text(
                      'Informações adicionais',
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.base),

                    AppTextField(
                      controller: _churchCtrl,
                      label: 'Igreja de origem (opcional)',
                      hint: 'Nome da sua igreja',
                      prefixIcon: Icons.church_outlined,
                      textInputAction: TextInputAction.done,
                    ),

                    const SizedBox(height: AppSpacing.xl2),

                    AppButton(
                      label: 'Encontrar Células Próximas',
                      prefixIcon: Icons.search_rounded,
                      isLoading: _isLoading,
                      onPressed: _submit,
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

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    // TODO: dispatch VisitorRegisterBloc event
  }
}
