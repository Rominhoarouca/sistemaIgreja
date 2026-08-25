import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../../../injection/injection.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class _EstadoInfo {
  final String id;
  final String name;
  final String uf;
  _EstadoInfo({required this.id, required this.name, required this.uf});
  factory _EstadoInfo.fromJson(Map<String, dynamic> j) => _EstadoInfo(
    id: j['id'] as String,
    name: j['name'] as String,
    uf: j['uf'] as String,
  );
}

class _CidadeInfo {
  final String id;
  final String name;
  final String estadoId;
  final String estadoUf;
  _CidadeInfo({
    required this.id,
    required this.name,
    required this.estadoId,
    required this.estadoUf,
  });
  factory _CidadeInfo.fromJson(Map<String, dynamic> j) => _CidadeInfo(
    id: j['id'] as String,
    name: j['name'] as String,
    estadoId: j['estadoId'] as String? ?? '',
    estadoUf: (j['estado'] as Map<String, dynamic>?)?['uf'] as String? ?? '',
  );
}

class _BairroInfo {
  final String id;
  final String name;
  final String cidadeId;
  final String cidadeName;
  _BairroInfo({
    required this.id,
    required this.name,
    required this.cidadeId,
    required this.cidadeName,
  });
  factory _BairroInfo.fromJson(Map<String, dynamic> j) => _BairroInfo(
    id: j['id'] as String,
    name: j['name'] as String,
    cidadeId: j['cidadeId'] as String? ?? '',
    cidadeName:
        (j['cidade'] as Map<String, dynamic>?)?['name'] as String? ?? '',
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Page — TabView: Cidades | Bairros
// ─────────────────────────────────────────────────────────────────────────────

class AdminLocationPage extends StatelessWidget {
  const AdminLocationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Localização'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.location_city_outlined), text: 'Cidades'),
              Tab(icon: Icon(Icons.location_on_outlined), text: 'Bairros'),
            ],
          ),
        ),
        body: const TabBarView(children: [_CidadesTab(), _BairrosTab()]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Cidades
// ─────────────────────────────────────────────────────────────────────────────

class _CidadesTab extends StatefulWidget {
  const _CidadesTab();
  @override
  State<_CidadesTab> createState() => _CidadesTabState();
}

class _CidadesTabState extends State<_CidadesTab> {
  late final Dio _dio;
  List<_EstadoInfo> _estados = [];
  _EstadoInfo? _selectedEstado;
  List<_CidadeInfo> _cidades = [];
  bool _loading = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _dio = getIt<DioClient>().dio;
    _loadEstados();
  }

  Future<void> _loadEstados() async {
    try {
      final r = await _dio.get('/location/estados');
      final list = (r.data as Map<String, dynamic>)['estados'] as List;
      if (!mounted) return;
      setState(
        () => _estados = list
            .map((e) => _EstadoInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {}
  }

  Future<void> _loadCidades(String estadoId) async {
    setState(() => _loading = true);
    try {
      final r = await _dio.get('/location/estados/$estadoId/cidades');
      final list = (r.data as Map<String, dynamic>)['cidades'] as List;
      if (!mounted) return;
      setState(
        () => _cidades = list
            .map((e) => _CidadeInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {
      if (mounted) setState(() => _cidades = []);
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _delete(_CidadeInfo cidade) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir cidade?'),
        content: Text(
          'A cidade "${cidade.name}" e todos seus bairros serão excluídos.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Excluir',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _dio.delete('/location/cidades/${cidade.id}');
      if (_selectedEstado != null) _loadCidades(_selectedEstado!.id);
    } on DioException catch (e) {
      if (!mounted) return;
      _snack(
        e.response?.data?['error']?['message'] as String? ?? 'Erro ao excluir',
      );
    }
  }

  void _snack(String msg, {Color color = AppColors.error}) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  Future<void> _showForm({_CidadeInfo? editing}) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    _EstadoInfo? estadoSel = editing != null
        ? _estados.firstWhere(
            (e) => e.id == editing.estadoId,
            orElse: () => _estados.first,
          )
        : _selectedEstado;

    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                editing == null ? 'Nova Cidade' : 'Editar Cidade',
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<_EstadoInfo>(
                initialValue: estadoSel,
                decoration: const InputDecoration(
                  labelText: 'Estado *',
                  border: OutlineInputBorder(),
                ),
                items: _estados
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text('${e.uf} — ${e.name}'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setS(() => estadoSel = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome da cidade *',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameCtrl.text.trim().isEmpty || estadoSel == null) {
                      return;
                    }
                    try {
                      if (editing == null) {
                        await _dio.post(
                          '/location/cidades',
                          data: {
                            'name': nameCtrl.text.trim(),
                            'estadoId': estadoSel!.id,
                          },
                        );
                      }
                      // Note: update not in API, just reload
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } on DioException catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(
                            content: Text(
                              e.response?.data?['error']?['message']
                                      as String? ??
                                  'Erro',
                            ),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    }
                  },
                  child: Text(editing == null ? 'Criar' : 'Salvar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (result == true && _selectedEstado != null) {
      _loadCidades(_selectedEstado!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _cidades
        .where((c) => c.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Stack(
      children: [
        Column(
          children: [
            // ── Estado selector ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: DropdownButtonFormField<_EstadoInfo>(
                initialValue: _selectedEstado,
                decoration: const InputDecoration(
                  labelText: 'Filtrar por estado',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.map_outlined),
                ),
                items: _estados
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text('${e.uf} — ${e.name}'),
                      ),
                    )
                    .toList(),
                onChanged: (e) {
                  setState(() {
                    _selectedEstado = e;
                    _cidades = [];
                    _search = '';
                  });
                  if (e != null) _loadCidades(e.id);
                },
              ),
            ),
            // ── Search ────────────────────────────────────────────────────
            if (_cidades.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Pesquisar cidade...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
            // ── List ──────────────────────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedEstado == null
                  ? const Center(child: Text('Selecione um estado'))
                  : filtered.isEmpty
                  ? const Center(child: Text('Nenhuma cidade encontrada'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        return ListTile(
                          leading: const Icon(
                            Icons.location_city_outlined,
                            color: AppColors.primary,
                          ),
                          title: Text(c.name),
                          subtitle: Text(c.estadoUf),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                            ),
                            onPressed: () => _delete(c),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        // ── FAB ────────────────────────────────────────────────────────
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            heroTag: 'fab_cidade',
            onPressed: () => _showForm(),
            icon: const Icon(Icons.add),
            label: const Text('Nova Cidade'),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab: Bairros
// ─────────────────────────────────────────────────────────────────────────────

class _BairrosTab extends StatefulWidget {
  const _BairrosTab();
  @override
  State<_BairrosTab> createState() => _BairrosTabState();
}

class _BairrosTabState extends State<_BairrosTab> {
  late final Dio _dio;
  List<_EstadoInfo> _estados = [];
  List<_CidadeInfo> _cidades = [];
  List<_BairroInfo> _bairros = [];
  _EstadoInfo? _selectedEstado;
  _CidadeInfo? _selectedCidade;
  bool _loadingCidades = false;
  bool _loadingBairros = false;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _dio = getIt<DioClient>().dio;
    _loadEstados();
  }

  Future<void> _loadEstados() async {
    try {
      final r = await _dio.get('/location/estados');
      final list = (r.data as Map<String, dynamic>)['estados'] as List;
      if (!mounted) return;
      setState(
        () => _estados = list
            .map((e) => _EstadoInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {}
  }

  Future<void> _loadCidades(String estadoId) async {
    setState(() {
      _loadingCidades = true;
      _cidades = [];
      _selectedCidade = null;
      _bairros = [];
    });
    try {
      final r = await _dio.get('/location/estados/$estadoId/cidades');
      final list = (r.data as Map<String, dynamic>)['cidades'] as List;
      if (!mounted) return;
      setState(
        () => _cidades = list
            .map((e) => _CidadeInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {}
    if (mounted) setState(() => _loadingCidades = false);
  }

  Future<void> _loadBairros(String cidadeId) async {
    setState(() {
      _loadingBairros = true;
      _bairros = [];
      _search = '';
    });
    try {
      final r = await _dio.get('/location/cidades/$cidadeId/bairros');
      final list = (r.data as Map<String, dynamic>)['bairros'] as List;
      if (!mounted) return;
      setState(
        () => _bairros = list
            .map((e) => _BairroInfo.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } catch (_) {}
    if (mounted) setState(() => _loadingBairros = false);
  }

  Future<void> _delete(_BairroInfo b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir bairro?'),
        content: Text('O bairro "${b.name}" será excluído.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Excluir',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _dio.delete('/location/bairros/${b.id}');
      if (_selectedCidade != null) _loadBairros(_selectedCidade!.id);
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?['message'] as String? ??
                'Erro ao excluir',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _showForm() async {
    if (_selectedCidade == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma cidade primeiro')),
      );
      return;
    }
    final nameCtrl = TextEditingController();
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Novo Bairro em ${_selectedCidade!.name}',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nome do bairro *',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  if (nameCtrl.text.trim().isEmpty) return;
                  try {
                    await _dio.post(
                      '/location/bairros',
                      data: {
                        'name': nameCtrl.text.trim(),
                        'cidadeId': _selectedCidade!.id,
                      },
                    );
                    if (context.mounted) Navigator.pop(context, true);
                  } on DioException catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            e.response?.data?['error']?['message'] as String? ??
                                'Erro',
                          ),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                },
                child: const Text('Criar bairro'),
              ),
            ),
          ],
        ),
      ),
    );
    if (result == true && _selectedCidade != null) {
      _loadBairros(_selectedCidade!.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _bairros
        .where((b) => b.name.toLowerCase().contains(_search.toLowerCase()))
        .toList();

    return Stack(
      children: [
        Column(
          children: [
            // ── Estado selector ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: DropdownButtonFormField<_EstadoInfo>(
                initialValue: _selectedEstado,
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.map_outlined),
                ),
                items: _estados
                    .map(
                      (e) => DropdownMenuItem(
                        value: e,
                        child: Text('${e.uf} — ${e.name}'),
                      ),
                    )
                    .toList(),
                onChanged: (e) {
                  setState(() {
                    _selectedEstado = e;
                    _selectedCidade = null;
                    _cidades = [];
                    _bairros = [];
                  });
                  if (e != null) _loadCidades(e.id);
                },
              ),
            ),
            // ── Cidade selector ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: _loadingCidades
                  ? const LinearProgressIndicator()
                  : DropdownButtonFormField<_CidadeInfo>(
                      initialValue: _selectedCidade,
                      decoration: const InputDecoration(
                        labelText: 'Cidade',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                      items: _cidades
                          .map(
                            (c) =>
                                DropdownMenuItem(value: c, child: Text(c.name)),
                          )
                          .toList(),
                      onChanged: _selectedEstado == null
                          ? null
                          : (c) {
                              setState(() {
                                _selectedCidade = c;
                                _bairros = [];
                              });
                              if (c != null) _loadBairros(c.id);
                            },
                    ),
            ),
            // ── Search ─────────────────────────────────────────────────
            if (_bairros.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Pesquisar bairro...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
            // ── List ───────────────────────────────────────────────────
            Expanded(
              child: _loadingBairros
                  ? const Center(child: CircularProgressIndicator())
                  : _selectedCidade == null
                  ? const Center(child: Text('Selecione estado e cidade'))
                  : filtered.isEmpty
                  ? const Center(child: Text('Nenhum bairro encontrado'))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final b = filtered[i];
                        return ListTile(
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: AppColors.primary,
                          ),
                          title: Text(b.name),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.error,
                            ),
                            onPressed: () => _delete(b),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        // ── FAB ────────────────────────────────────────────────────────
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.extended(
            onPressed: _showForm,
            icon: const Icon(Icons.add),
            label: const Text('Novo Bairro'),
          ),
        ),
      ],
    );
  }
}
