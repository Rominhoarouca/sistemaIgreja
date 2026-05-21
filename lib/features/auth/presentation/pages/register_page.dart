import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../design_system/design_system.dart';
import '../bloc/auth_bloc.dart';

/// Register page — creates a new LIDER account.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
      AuthRegisterRequested(
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          // After registration the user is always a leader
          context.go('/leader');
        } else if (state is AuthError) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppColors.error,
              ),
            );
        }
      },
      child: BlocBuilder<AuthBloc, AuthState>(
        builder: (context, state) {
          final isLoading = state is AuthLoading;

          return Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // ── Header ───────────────────────────────────────────
                    AppGradientHeader(
                      height: 220,
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
                                  Icons.person_add_outlined,
                                  size: 48,
                                  color: AppColors.white,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Criar conta',
                                  style: AppTypography.headlineSmall.copyWith(
                                    color: AppColors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Cadastro para líderes',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.white.withValues(
                                      alpha: 0.75,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Form ─────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSpacing.base),
                            Text(
                              'Seus dados',
                              style: AppTypography.headlineSmall,
                            ),
                            Text(
                              'Preencha as informações para criar sua conta',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),

                            AppTextField(
                              controller: _nameCtrl,
                              label: 'Nome completo',
                              hint: 'Seu nome',
                              prefixIcon: Icons.person_outline,
                              textInputAction: TextInputAction.next,
                              enabled: !isLoading,
                              validator: (v) {
                                if (v == null || v.trim().length < 2) {
                                  return 'Informe seu nome (mín. 2 caracteres)';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.base),

                            AppTextField(
                              controller: _emailCtrl,
                              label: 'E-mail',
                              hint: 'seu@email.com',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              enabled: !isLoading,
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Informe seu e-mail';
                                }
                                if (!v.contains('@')) return 'E-mail inválido';
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.base),

                            AppTextField(
                              controller: _passwordCtrl,
                              label: 'Senha',
                              hint: '••••••••',
                              prefixIcon: Icons.lock_outline,
                              obscureText: _obscurePassword,
                              suffixIcon: _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              onSuffixTap: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              textInputAction: TextInputAction.next,
                              enabled: !isLoading,
                              validator: (v) {
                                if (v == null || v.length < 6) {
                                  return 'Mínimo 6 caracteres';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.base),

                            AppTextField(
                              controller: _confirmPasswordCtrl,
                              label: 'Confirmar senha',
                              hint: '••••••••',
                              prefixIcon: Icons.lock_outline,
                              obscureText: _obscureConfirm,
                              suffixIcon: _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              onSuffixTap: () => setState(
                                () => _obscureConfirm = !_obscureConfirm,
                              ),
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              enabled: !isLoading,
                              validator: (v) {
                                if (v != _passwordCtrl.text) {
                                  return 'As senhas não coincidem';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: AppSpacing.xl),

                            AppButton(
                              label: 'Criar conta',
                              isLoading: isLoading,
                              onPressed: _submit,
                              prefixIcon: Icons.person_add_outlined,
                            ),

                            const SizedBox(height: AppSpacing.base),
                            Center(
                              child: TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () => context.pop(),
                                child: const Text(
                                  'Já tenho uma conta — Entrar',
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl2),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
