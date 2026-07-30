import 'package:flutter/material.dart';
import '../../../../injection/injection.dart';
import '../../data/church_remote_datasource.dart';
import '../../domain/church_context.dart';

/// Super-admin: CRUD de planos (valores, descrição e features de cada plano).
/// A seleção de features reflete automaticamente nas igrejas do plano.
class PlanManagementPage extends StatefulWidget {
  const PlanManagementPage({super.key});

  @override
  State<PlanManagementPage> createState() => _PlanManagementPageState();
}

class _PlanManagementPageState extends State<PlanManagementPage> {
  final _ds = getIt<ChurchRemoteDatasource>();

  List<PlanInfo> _plans = const [];
  List<FeatureCatalogItem> _catalog = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _ds.listAllPlans(),
        _ds.getFeatureCatalog(),
      ]);
      if (mounted) {
        setState(() {
          _plans = results[0] as List<PlanInfo>;
          _catalog = results[1] as List<FeatureCatalogItem>;
        });
      }
    } catch (e) {
      _snack('Erro ao carregar: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  String _label(String key) =>
      _catalog.firstWhere((c) => c.key == key,
          orElse: () => FeatureCatalogItem(key: key, label: key, description: '')).label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Planos'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Defina preços, descrição e as funcionalidades de cada plano. '
                    'As funcionalidades marcadas são liberadas para as igrejas desse plano.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  ..._plans.map(_planCard),
                ],
              ),
            ),
    );
  }

  Widget _planCard(PlanInfo p) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('${p.name}  ·  ${p.tier}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                Text(p.priceMonthLabel,
                    style: TextStyle(color: Theme.of(context).colorScheme.primary)),
              ],
            ),
            if (p.description != null && p.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(p.description!, style: const TextStyle(color: Colors.grey)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: p.features.isEmpty
                  ? [const Chip(label: Text('Somente recursos básicos'))]
                  : p.features.map((f) => Chip(label: Text(_label(f)))).toList(),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                onPressed: () => _editPlan(p),
                icon: const Icon(Icons.edit, size: 18),
                label: const Text('Editar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editPlan(PlanInfo p) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlanEditor(plan: p, catalog: _catalog, ds: _ds),
    );
    if (saved == true) {
      _snack('Plano ${p.name} atualizado');
      await _load();
    }
  }
}

/// Editor de um plano (bottom sheet).
class _PlanEditor extends StatefulWidget {
  const _PlanEditor({required this.plan, required this.catalog, required this.ds});

  final PlanInfo plan;
  final List<FeatureCatalogItem> catalog;
  final ChurchRemoteDatasource ds;

  @override
  State<_PlanEditor> createState() => _PlanEditorState();
}

class _PlanEditorState extends State<_PlanEditor> {
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _priceMonth;
  late final TextEditingController _priceYear;
  late Set<String> _features;
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _name = TextEditingController(text: p.name);
    _description = TextEditingController(text: p.description ?? '');
    _priceMonth = TextEditingController(text: (p.priceMonth / 100).toStringAsFixed(2));
    _priceYear = TextEditingController(text: (p.priceYear / 100).toStringAsFixed(2));
    _features = p.features.toSet();
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _priceMonth, _priceYear]) {
      c.dispose();
    }
    super.dispose();
  }

  int _toCents(String v) {
    final normalized = v.replaceAll('.', '').replaceAll(',', '.');
    final value = double.tryParse(normalized) ?? 0;
    return (value * 100).round();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.ds.upsertPlan(
        tier: widget.plan.tier,
        name: _name.text.trim(),
        description: _description.text.trim().isEmpty ? null : _description.text.trim(),
        priceMonth: _toCents(_priceMonth.text),
        priceYear: _toCents(_priceYear.text),
        features: _features.toList(),
        isActive: _active,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erro: $e')));
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Editar plano ${widget.plan.tier}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              decoration: const InputDecoration(
                  labelText: 'Nome do plano', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(
                  labelText: 'Descrição', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceMonth,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Preço mensal (R\$)',
                        prefixText: 'R\$ ',
                        border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _priceYear,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'Preço anual (R\$)',
                        prefixText: 'R\$ ',
                        border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text('Funcionalidades incluídas',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text('O que estiver marcado é liberado para as igrejas deste plano.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 8),
            ...widget.catalog.map((f) => CheckboxListTile(
                  value: _features.contains(f.key),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _features.add(f.key);
                    } else {
                      _features.remove(f.key);
                    }
                  }),
                  title: Text(f.label),
                  subtitle: Text(f.description),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                )),
            const Divider(),
            SwitchListTile(
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: const Text('Plano ativo'),
              subtitle: const Text('Planos inativos não aparecem para novas assinaturas'),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save),
              label: const Text('Salvar plano'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
