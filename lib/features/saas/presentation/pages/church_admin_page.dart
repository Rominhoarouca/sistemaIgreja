import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../injection/injection.dart';
import '../../data/church_remote_datasource.dart';
import '../../domain/church_context.dart';
import '../church_context_controller.dart';

/// Área administrativa da igreja (ADMIN): dados, redes sociais, cor do menu e logo.
class ChurchAdminPage extends StatefulWidget {
  const ChurchAdminPage({super.key});

  @override
  State<ChurchAdminPage> createState() => _ChurchAdminPageState();
}

class _ChurchAdminPageState extends State<ChurchAdminPage> {
  final _ds = getIt<ChurchRemoteDatasource>();
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _address = TextEditingController();
  final _site = TextEditingController();
  final _instagram = TextEditingController();
  final _youtube = TextEditingController();
  final _tiktok = TextEditingController();

  String _menuColor = '#3F51B5';
  bool _saving = false;
  bool _uploading = false;
  bool _changingPlan = false;
  List<PlanInfo> _plans = const [];

  static const _palette = [
    '#3F51B5', '#1E3A8A', '#0EA5E9', '#059669', '#16A34A',
    '#CA8A04', '#EA580C', '#DC2626', '#DB2777', '#7C3AED', '#0F172A',
  ];

  @override
  void initState() {
    super.initState();
    final c = ChurchContextController.instance.church;
    if (c != null) _fill(c);
    _loadPlans();
  }

  Future<void> _loadPlans() async {
    try {
      final plans = await _ds.listActivePlans();
      if (mounted) setState(() => _plans = plans);
    } catch (_) {
      // Sem a lista, o card do plano continua mostrando só o plano atual.
    }
  }

  /// Troca o plano da igreja. Quando o gateway exige pagamento online a API
  /// devolve a URL do checkout; caso contrário o plano já vale na hora.
  Future<void> _changePlan(PlanInfo plan) async {
    // O "cliente" da cobrança é a igreja; o e-mail é o do admin logado.
    final church = ChurchContextController.instance.church;
    final authState = context.read<AuthBloc>().state;
    final adminEmail = authState is AuthAuthenticated
        ? authState.user.email
        : null;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Mudar para o plano ${plan.name}?'),
        content: Text(
          plan.priceMonth == 0
              ? 'O plano ${plan.name} é gratuito. Recursos fora dele deixam de '
                    'ficar disponíveis.'
              : 'Valor: ${plan.priceMonthLabel}. Se a cobrança online estiver '
                    'ativa, você será levado ao checkout.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _changingPlan = true);
    try {
      final checkoutUrl = await _ds.changePlan(
        planTier: plan.tier,
        customerName: church?.name,
        customerEmail: adminEmail,
      );
      if (checkoutUrl != null) {
        final uri = Uri.parse(checkoutUrl);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _snack('Finalize o pagamento para ativar o plano');
      } else {
        await ChurchContextController.instance.load();
        _snack('Plano alterado para ${plan.name}');
      }
    } catch (e) {
      _snack('Erro ao alterar o plano: $e', error: true);
    } finally {
      if (mounted) setState(() => _changingPlan = false);
    }
  }

  void _fill(ChurchInfo c) {
    _name.text = c.name;
    _address.text = c.address ?? '';
    _site.text = c.site ?? '';
    _instagram.text = c.instagram ?? '';
    _youtube.text = c.youtube ?? '';
    _tiktok.text = c.tiktok ?? '';
    _menuColor = c.menuColorHex;
  }

  @override
  void dispose() {
    for (final c in [_name, _address, _site, _instagram, _youtube, _tiktok]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final church = await _ds.updateChurch({
        'name': _name.text.trim(),
        'address': _address.text.trim().isEmpty ? null : _address.text.trim(),
        'site': _site.text.trim().isEmpty ? null : _site.text.trim(),
        'instagram': _instagram.text.trim().isEmpty ? null : _instagram.text.trim(),
        'youtube': _youtube.text.trim().isEmpty ? null : _youtube.text.trim(),
        'tiktok': _tiktok.text.trim().isEmpty ? null : _tiktok.text.trim(),
        'menuColor': _menuColor,
      });
      ChurchContextController.instance.updateChurchLocal(church);
      _snack('Dados da igreja atualizados');
    } catch (e) {
      _snack('Erro ao salvar: $e', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null || file.bytes == null) return;

    setState(() => _uploading = true);
    try {
      await _ds.uploadLogo(bytes: file.bytes!, filename: file.name);
      await ChurchContextController.instance.load();
      _snack('Logo atualizada');
    } catch (e) {
      _snack('Erro ao enviar logo: $e', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red.shade700 : null,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ChurchContextController.instance,
      builder: (context, _) {
        final ctx = ChurchContextController.instance.context;
        final plan = ctx?.plan;
        return Scaffold(
          appBar: AppBar(title: const Text('Configurações da Igreja')),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _logoCard(ctx?.church.logoUrl),
                      const SizedBox(height: 20),
                      if (plan != null) _planCard(plan, ctx?.subscriptionStatus),
                      const SizedBox(height: 20),
                      _sectionTitle('Identificação'),
                      _field(_name, 'Nome da igreja', required: true),
                      _field(_address, 'Endereço'),
                      _field(_site, 'Site'),
                      const SizedBox(height: 12),
                      _sectionTitle('Redes sociais'),
                      _field(_instagram, 'Instagram', icon: Icons.camera_alt_outlined),
                      _field(_youtube, 'YouTube', icon: Icons.play_circle_outline),
                      _field(_tiktok, 'TikTok', icon: Icons.music_note_outlined),
                      const SizedBox(height: 12),
                      _sectionTitle('Cor do menu'),
                      _colorPicker(),
                      const SizedBox(height: 28),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save),
                        label: const Text('Salvar alterações'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _logoCard(String? logoUrl) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                image: logoUrl != null
                    ? DecorationImage(image: NetworkImage(logoUrl), fit: BoxFit.cover)
                    : null,
              ),
              child: logoUrl == null
                  ? const Icon(Icons.church_outlined, size: 40, color: Colors.grey)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Logo da igreja',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  const Text('PNG, JPG, WEBP ou SVG (até 5 MB)',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _uploading ? null : _pickLogo,
                    icon: _uploading
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.upload),
                    label: Text(logoUrl == null ? 'Enviar logo' : 'Trocar logo'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _planCard(PlanInfo plan, String? status) {
    final others = _plans.where((p) => p.tier != plan.tier).toList();
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text('Plano ${plan.name}'),
            subtitle: Text(
              '${plan.priceMonthLabel}${status != null ? ' • $status' : ''}',
            ),
          ),
          if (others.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mudar de plano',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final other in others)
                        OutlinedButton(
                          onPressed: _changingPlan
                              ? null
                              : () => _changePlan(other),
                          child: Text(
                            '${other.name} · ${other.priceMonthLabel}',
                          ),
                        ),
                    ],
                  ),
                  if (_changingPlan)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );

  Widget _field(TextEditingController c, String label,
      {bool required = false, IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon != null ? Icon(icon) : null,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null
            : null,
      ),
    );
  }

  Widget _colorPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _palette.map((hex) {
        final selected = hex.toUpperCase() == _menuColor.toUpperCase();
        return GestureDetector(
          onTap: () => setState(() => _menuColor = hex),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _hex(hex),
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.black : Colors.transparent,
                width: 3,
              ),
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Color _hex(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }
}
