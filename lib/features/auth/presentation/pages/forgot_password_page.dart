import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../design_system/design_system.dart';

/// Forgot password page — user enters email to receive a reset link.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // TODO: wire to AuthRepository.forgotPassword when the API implements it.
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _sent = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 720;
    final formContent = Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // ── Header ─────────────────────────────────────────────────
              AppGradientHeader(
                height: 200,
                child: Stack(
                  children: [
                    Positioned(
                      top: 16,
                      left: 8,
                      child: BackButton(
                        color: AppColors.white,
                        onPressed: () => context.pop(),
                      ),
                    ),
                    Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.lock_reset_outlined,
                            size: 48,
                            color: AppColors.white,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Esqueci minha senha',
                            style: AppTypography.headlineSmall.copyWith(
                              color: AppColors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Content ────────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
                child: _sent
                    ? _SuccessContent(email: _emailCtrl.text.trim())
                    : _FormContent(
                        formKey: _formKey,
                        emailCtrl: _emailCtrl,
                        isLoading: _isLoading,
                        onSubmit: _submit,
                        onBack: () => context.pop(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!isWide) return formContent;
    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl2),
            child: SizedBox(
              width: 500,
              child: Material(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                elevation: 16,
                clipBehavior: Clip.antiAlias,
                child: formContent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FormContent extends StatelessWidget {
  const _FormContent({
    required this.formKey,
    required this.emailCtrl,
    required this.isLoading,
    required this.onSubmit,
    required this.onBack,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final bool isLoading;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.base),
          Text('Redefinir senha', style: AppTypography.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Informe seu e-mail cadastrado e enviaremos as instruções para criar uma nova senha.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),

          AppTextField(
            controller: emailCtrl,
            label: 'E-mail',
            hint: 'seu@email.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            enabled: !isLoading,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Informe seu e-mail';
              if (!v.contains('@')) return 'E-mail inválido';
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          AppButton(
            label: 'Enviar instruções',
            isLoading: isLoading,
            onPressed: onSubmit,
            prefixIcon: Icons.send_outlined,
          ),
          const SizedBox(height: AppSpacing.base),
          Center(
            child: TextButton(
              onPressed: isLoading ? null : onBack,
              child: const Text('Voltar para o login'),
            ),
          ),
          const SizedBox(height: AppSpacing.xl2),
        ],
      ),
    );
  }
}

class _SuccessContent extends StatelessWidget {
  const _SuccessContent({required this.email});

  final String email;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.xl2),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            size: 40,
            color: AppColors.success,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        Text('E-mail enviado!', style: AppTypography.headlineSmall),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Verifique sua caixa de entrada em\n$email\ne siga as instruções para redefinir sua senha.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.xl2),
        AppButton(
          label: 'Voltar para o login',
          variant: AppButtonVariant.outline,
          prefixIcon: Icons.arrow_back,
          onPressed: () => context.go('/login'),
        ),
        const SizedBox(height: AppSpacing.xl2),
      ],
    );
  }
}
