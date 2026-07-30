import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../design_system/design_system.dart';
import '../bloc/auth_bloc.dart';

/// Login page — RNF01 (authentication)
/// Desktop: split-screen com painel navy 46% (logo + headline) e formulário
/// 380px à direita. Mobile: tela cheia com gradiente navy e inputs
/// translúcidos. (design_handoff_sistema_igreja)
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  static const _rememberKey = 'remembered_email';

  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String _appVersion = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
    _loadRememberedEmail();
    if (kDebugMode) {
      _fillDevCredentials();
    }
  }

  Future<void> _loadVersion() async {
    final info = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() => _appVersion = 'v${info.version}');
    }
  }

  Future<void> _loadRememberedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_rememberKey);
    if (email != null && email.isNotEmpty && mounted) {
      setState(() {
        _emailCtrl.text = email;
        _rememberMe = true;
      });
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

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final prefs = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await prefs.setString(_rememberKey, _emailCtrl.text.trim().toLowerCase());
    } else {
      await prefs.remove(_rememberKey);
    }
    if (!mounted) return;
    context.read<AuthBloc>().add(
      AuthLoginRequested(
        email: _emailCtrl.text.trim().toLowerCase(),
        password: _passwordCtrl.text,
      ),
    );
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Informe seu e-mail';
    if (!v.contains('@')) return 'E-mail inválido';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.length < 6) return 'Mínimo 6 caracteres';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        // Navigation on AuthAuthenticated is handled by the GoRouter redirect.
        if (state is AuthError) {
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
          final isWide = MediaQuery.sizeOf(context).width >= 900;
          return isWide
              ? _buildDesktop(context, isLoading)
              : _buildMobile(context, isLoading);
        },
      ),
    );
  }

  // ── Desktop: split-screen ──────────────────────────────────────────────────

  Widget _buildDesktop(BuildContext context, bool isLoading) {
    return Scaffold(
      body: Row(
        children: [
          // Painel de marca 46% — gradiente navy.
          Expanded(
            flex: 46,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.navy900,
                    AppColors.navy800,
                    AppColors.primary,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _logoBadge(size: 56),
                      const Spacer(),
                      Text(
                        'Receber bem é o\nprimeiro passo.',
                        style: AppTypography.displayLarge.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.base),
                      Text(
                        'Sistema de recepção e integração — conecte '
                        'visitantes a líderes e células da igreja.',
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.white.withValues(alpha: .72),
                        ),
                      ),
                      const Spacer(),
                      if (_appVersion.isNotEmpty)
                        Text(
                          'Sistema Igreja · $_appVersion',
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.white.withValues(alpha: .45),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Formulário 380px.
          Expanded(
            flex: 54,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.xl2),
                child: SizedBox(width: 380, child: _buildForm(isLoading)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(bool isLoading) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bem-vindo de volta', style: AppTypography.headlineSmall),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Acesse sua conta para continuar',
            style: AppTypography.bodyMedium.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xl2),
          if (kDebugMode) ...[
            _devCredentialsCard(theme),
            const SizedBox(height: AppSpacing.base),
          ],
          AppTextField(
            controller: _emailCtrl,
            label: 'E-mail',
            hint: 'seu@email.com',
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: _validateEmail,
          ),
          const SizedBox(height: AppSpacing.fieldGap),
          AppTextField(
            controller: _passwordCtrl,
            label: 'Senha',
            hint: '••••••••',
            prefixIcon: Icons.lock_outline,
            obscureText: _obscurePassword,
            suffixIcon: _obscurePassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            onSuffixTap: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            validator: _validatePassword,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: _rememberMe,
                  onChanged: (v) => setState(() => _rememberMe = v ?? false),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Lembrar-me', style: AppTypography.bodySmall),
              const Spacer(),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () => context.push('/forgot-password'),
                child: const Text('Esqueci minha senha'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.base),
          SizedBox(
            height: AppSpacing.buttonHeightLg,
            child: AppButton(
              label: 'Entrar',
              isLoading: isLoading,
              onPressed: _submit,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const Divider(),
          const SizedBox(height: AppSpacing.base),
          Center(
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'É visitante? ',
                  style: AppTypography.bodyMedium.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => context.push(AppRoutes.visitorSelfRegister),
                  child: const Text('Faça seu cadastro'),
                ),
              ],
            ),
          ),
          Center(
            child: TextButton(
              onPressed: isLoading
                  ? null
                  : () => context.push(AppRoutes.register),
              child: Text(
                'Criar conta de acesso',
                style: AppTypography.bodySmall.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Center(
            child: TextButton.icon(
              onPressed: isLoading ? null : () => context.push(AppRoutes.signup),
              icon: const Icon(Icons.add_business_outlined, size: 18),
              label: Text(
                'Cadastrar minha igreja',
                style: AppTypography.bodySmall.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _devCredentialsCard(ThemeData theme) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Credenciais de desenvolvimento', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'admin@sistemaigreja.com.br · admin123',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _fillDevCredentials,
            child: const Text('Usar credenciais'),
          ),
        ),
      ],
    ),
  );

  // ── Mobile: tela cheia navy com inputs translúcidos ────────────────────────

  Widget _buildMobile(BuildContext context, bool isLoading) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.xl2),
                    Center(child: _logoBadge(size: 72)),
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: Text(
                        'Sistema Igreja',
                        style: AppTypography.headlineSmall.copyWith(
                          color: AppColors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Center(
                      child: Text(
                        'Recepção & Integração',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.white.withValues(alpha: .7),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl3),
                    _translucentField(
                      controller: _emailCtrl,
                      label: 'E-mail',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: _validateEmail,
                    ),
                    const SizedBox(height: AppSpacing.fieldGap),
                    _translucentField(
                      controller: _passwordCtrl,
                      label: 'Senha',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      suffix: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.white.withValues(alpha: .7),
                          size: 20,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (v) =>
                                setState(() => _rememberMe = v ?? false),
                            side: BorderSide(
                              color: AppColors.white.withValues(alpha: .5),
                            ),
                            checkColor: AppColors.navy900,
                            activeColor: AppColors.gold,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Lembrar-me',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.white.withValues(alpha: .8),
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: isLoading
                              ? null
                              : () => context.push('/forgot-password'),
                          child: Text(
                            'Esqueci minha senha',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.white.withValues(alpha: .85),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Botão Entrar branco sobre navy.
                    SizedBox(
                      height: AppSpacing.buttonHeightLg,
                      child: FilledButton(
                        onPressed: isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.white,
                          foregroundColor: AppColors.navy900,
                          textStyle: AppTypography.buttonLabel,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppSpacing.radiusMd,
                            ),
                          ),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: AppColors.navy900,
                                ),
                              )
                            : const Text('Entrar'),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Center(
                      child: TextButton(
                        onPressed: isLoading
                            ? null
                            : () => context.push(AppRoutes.visitorSelfRegister),
                        child: Text(
                          'É visitante? Faça seu cadastro',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.white,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.white.withValues(
                              alpha: .5,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Center(
                      child: TextButton(
                        onPressed: isLoading
                            ? null
                            : () => context.push(AppRoutes.register),
                        child: Text(
                          'Criar conta de acesso',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.white.withValues(alpha: .6),
                          ),
                        ),
                      ),
                    ),
                    if (_appVersion.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.base),
                      Center(
                        child: Text(
                          _appVersion,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.white.withValues(alpha: .4),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _translucentField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffix,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
    String? Function(String?)? validator,
  }) {
    final white = AppColors.white;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      validator: validator,
      style: AppTypography.bodyLarge.copyWith(color: white),
      cursorColor: AppColors.gold,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppTypography.bodyMedium.copyWith(
          color: white.withValues(alpha: .7),
        ),
        prefixIcon: Icon(icon, color: white.withValues(alpha: .7), size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: white.withValues(alpha: .08),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: BorderSide(color: white.withValues(alpha: .2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: Color(0xFFFFB4A9)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          borderSide: const BorderSide(color: Color(0xFFFFB4A9), width: 1.5),
        ),
        errorStyle: AppTypography.labelSmall.copyWith(
          color: const Color(0xFFFFB4A9),
        ),
      ),
    );
  }

  Widget _logoBadge({required double size}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: AppColors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
    ),
    clipBehavior: Clip.antiAlias,
    child: Image.asset(
      'assets/images/logo.png',
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) =>
          const Icon(Icons.church_outlined, color: AppColors.gold),
    ),
  );
}
