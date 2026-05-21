import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../design_system/design_system.dart';
import '../bloc/auth_bloc.dart';

/// Login page — RNF01 (authentication)
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    if (kDebugMode) {
      _fillDevCredentials();
    }
  }

  void _fillDevCredentials() {
    _emailCtrl.text = 'admin@sistemaigreja.com.br';
    _passwordCtrl.text = 'admin123';
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
      AuthLoginRequested(
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
          final destination = state.user.isAdmin
              ? AppRoutes.adminDashboard
              : AppRoutes.leaderHome;
          context.go(destination);
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
                    // ── Logo Area ──────────────────────────────────────────────
                    AppGradientHeader(
                      height: 280,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                color: AppColors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusXl,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusXl,
                                ),
                                child: Image.asset(
                                  'assets/images/logo App.png',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.base),
                            Text(
                              'Sistema Igreja',
                              style: AppTypography.headlineSmall.copyWith(
                                color: AppColors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            Text(
                              'Recepção & Integração',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.white.withValues(alpha: 0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ── Form Card ──────────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppSpacing.base),
                            Text('Entrar', style: AppTypography.headlineSmall),
                            Text(
                              'Acesse sua conta para continuar',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xl),

                            if (kDebugMode) ...[
                              AppCard(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Credenciais de desenvolvimento',
                                      style: AppTypography.titleSmall,
                                    ),
                                    const SizedBox(height: AppSpacing.xs),
                                    Text(
                                      'E-mail: admin@sistemaigreja.com.br',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Text(
                                      'Senha: admin123',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.sm),
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: TextButton(
                                        onPressed: _fillDevCredentials,
                                        child: const Text('Usar credenciais'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.base),
                            ],

                            AppTextField(
                              controller: _emailCtrl,
                              label: 'E-mail',
                              hint: 'seu@email.com',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
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
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              validator: (v) {
                                if (v == null || v.length < 6) {
                                  return 'Mínimo 6 caracteres';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: AppSpacing.sm),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: isLoading
                                    ? null
                                    : () => context.push('/forgot-password'),
                                child: const Text('Esqueci minha senha'),
                              ),
                            ),

                            const SizedBox(height: AppSpacing.base),
                            AppButton(
                              label: 'Entrar',
                              isLoading: isLoading,
                              onPressed: _submit,
                              prefixIcon: Icons.login,
                            ),

                            const SizedBox(height: AppSpacing.xl),
                            const Divider(),
                            const SizedBox(height: AppSpacing.base),

                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    'Novo por aqui?',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  AppButton(
                                    label: 'Fazer cadastro',
                                    variant: AppButtonVariant.outline,
                                    prefixIcon: Icons.person_add_outlined,
                                    onPressed: isLoading
                                        ? null
                                        : () =>
                                              context.push(AppRoutes.register),
                                  ),
                                ],
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
