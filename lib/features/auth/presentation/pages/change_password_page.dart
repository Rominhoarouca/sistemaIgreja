import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../design_system/design_system.dart';

/// Change Password page — authenticated user changes their password.
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    // TODO: wire to API when endpoint is implemented
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Senha alterada com sucesso!'),
        backgroundColor: AppColors.success,
      ),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        title: const Text('Alterar Senha'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xl),

                // Icon header
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline,
                      size: 48,
                      color: AppColors.primary,
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.xl),

                Text(
                  'Para sua segurança, insira a senha atual antes de definir a nova.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.xl2),

                AppTextField(
                  controller: _currentCtrl,
                  label: 'Senha atual',
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outline,
                  obscureText: !_showCurrent,
                  suffixIcon: _showCurrent
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  onSuffixTap: () =>
                      setState(() => _showCurrent = !_showCurrent),
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Informe a senha atual' : null,
                ),

                const SizedBox(height: AppSpacing.base),

                AppTextField(
                  controller: _newCtrl,
                  label: 'Nova senha',
                  hint: '••••••••',
                  prefixIcon: Icons.lock_reset_outlined,
                  obscureText: !_showNew,
                  suffixIcon: _showNew
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  onSuffixTap: () => setState(() => _showNew = !_showNew),
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Informe a nova senha';
                    if (v.length < 6) return 'Mínimo 6 caracteres';
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.base),

                AppTextField(
                  controller: _confirmCtrl,
                  label: 'Confirmar nova senha',
                  hint: '••••••••',
                  prefixIcon: Icons.lock_outline,
                  obscureText: !_showConfirm,
                  suffixIcon: _showConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  onSuffixTap: () =>
                      setState(() => _showConfirm = !_showConfirm),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submit(),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Confirme a nova senha';
                    if (v != _newCtrl.text) return 'As senhas não coincidem';
                    return null;
                  },
                ),

                const SizedBox(height: AppSpacing.xl2),

                AppButton(
                  label: 'Alterar senha',
                  prefixIcon: Icons.check,
                  isLoading: _isLoading,
                  onPressed: _submit,
                ),

                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
