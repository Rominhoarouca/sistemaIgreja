import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/auth_storage.dart';
import '../../../../injection/injection.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../data/church_remote_datasource.dart';
import '../../domain/church_context.dart';

/// Cadastro público self-service de uma nova igreja (SaaS).
class ChurchSignupPage extends StatefulWidget {
  const ChurchSignupPage({super.key});

  @override
  State<ChurchSignupPage> createState() => _ChurchSignupPageState();
}

class _ChurchSignupPageState extends State<ChurchSignupPage> {
  final _ds = getIt<ChurchRemoteDatasource>();
  final _formKey = GlobalKey<FormState>();

  final _churchName = TextEditingController();
  final _adminName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _planTier = 'FREE';
  List<PlanInfo> _plans = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await _ds.listActivePlans();
      if (mounted) setState(() => _plans = plans);
    } catch (_) {/* rede: segue com FREE */}
  }

  @override
  void dispose() {
    for (final c in [_churchName, _adminName, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final res = await _ds.signupChurch(
        churchName: _churchName.text.trim(),
        adminName: _adminName.text.trim(),
        adminEmail: _email.text.trim(),
        adminPassword: _password.text,
        planTier: _planTier,
      );
      final access = res['accessToken'] as String;
      final refresh = res['refreshToken'] as String;
      await getIt<AuthStorage>().saveTokens(access: access, refresh: refresh);
      // Reavalia a sessão → router redireciona para o painel do admin.
      getIt<AuthBloc>().add(const AuthCheckRequested());
      if (mounted) context.go(AppRoutes.adminDashboard);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao cadastrar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Criar conta da igreja')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Comece agora',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Cadastre sua igreja e escolha um plano.',
                      style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  _field(_churchName, 'Nome da igreja', required: true),
                  _field(_adminName, 'Seu nome (administrador)', required: true),
                  _field(_email, 'E-mail', required: true, email: true),
                  _field(_password, 'Senha', required: true, obscure: true),
                  const SizedBox(height: 8),
                  if (_plans.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Plano', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                    ..._plans.map(_planTile),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20, width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Criar igreja'),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.login),
                    child: const Text('Já tenho conta'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _planTile(PlanInfo p) {
    final selected = _planTier == p.tier;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _planTier = p.tier),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey.shade300,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                  color: selected ? Theme.of(context).colorScheme.primary : Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${p.name} — ${p.priceMonthLabel}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (p.description != null)
                      Text(p.description!,
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool required = false, bool email = false, bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        obscureText: obscure,
        keyboardType: email ? TextInputType.emailAddress : null,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: (v) {
          if (required && (v == null || v.trim().isEmpty)) return 'Campo obrigatório';
          if (email && v != null && !v.contains('@')) return 'E-mail inválido';
          if (obscure && v != null && v.length < 6) return 'Mínimo 6 caracteres';
          return null;
        },
      ),
    );
  }
}
