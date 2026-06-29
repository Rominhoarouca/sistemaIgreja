import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../design_system/design_system.dart';
import '../../../core/constants/app_constants.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Internal data models
// ─────────────────────────────────────────────────────────────────────────────

class _EstadoOption {
  final String id;
  final String name;
  final String uf;
  _EstadoOption({required this.id, required this.name, required this.uf});
  factory _EstadoOption.fromJson(Map<String, dynamic> j) => _EstadoOption(
    id: j['id'] as String,
    name: j['name'] as String,
    uf: j['uf'] as String,
  );
  String get label => '${uf.toUpperCase()} — $name';
}

class _CidadeOption {
  final String id;
  final String name;
  _CidadeOption({required this.id, required this.name});
  factory _CidadeOption.fromJson(Map<String, dynamic> j) =>
      _CidadeOption(id: j['id'] as String, name: j['name'] as String);
}

class _BairroOption {
  final String id;
  final String name;
  _BairroOption({required this.id, required this.name});
  factory _BairroOption.fromJson(Map<String, dynamic> j) =>
      _BairroOption(id: j['id'] as String, name: j['name'] as String);
}

// ─────────────────────────────────────────────────────────────────────────────
// AddressSelector — 3 cascading searchable dropdowns: Estado → Cidade → Bairro
// ─────────────────────────────────────────────────────────────────────────────

/// Searchable/filterable cascading address selector.
/// Each level can be typed into to filter the options.
/// Calls [onChanged] with the selected bairroId (or null when cleared).
/// [dio] is optional — if omitted, a fresh unauthenticated Dio is created
/// (the /v1/location endpoints are public).
class AddressSelector extends StatefulWidget {
  const AddressSelector({
    super.key,
    required this.onChanged,
    this.initialBairroId,
    this.initialEstadoId,
    this.initialCidadeId,
    this.onEstadoChanged,
    this.onCidadeChanged,
    this.dio,
    this.isRequired = true,
  });

  final void Function(String? bairroId) onChanged;
  final String? initialBairroId;
  final String? initialEstadoId;
  final String? initialCidadeId;
  final void Function(String? estadoId)? onEstadoChanged;
  final void Function(String? cidadeId)? onCidadeChanged;

  /// Optional authenticated Dio. When null, a public Dio is used.
  final Dio? dio;

  /// If true, shows validation error when bairro is not selected.
  final bool isRequired;

  @override
  State<AddressSelector> createState() => _AddressSelectorState();
}

class _AddressSelectorState extends State<AddressSelector> {
  late final Dio _dio;

  List<_EstadoOption> _estados = [];
  List<_CidadeOption> _cidades = [];
  List<_BairroOption> _bairros = [];

  _EstadoOption? _estado;
  _CidadeOption? _cidade;
  _BairroOption? _bairro;

  bool _loadingEstados = false;
  bool _loadingCidades = false;
  bool _loadingBairros = false;

  // Keys used to force Autocomplete to rebuild (clears text) when parent changes
  Key _cidadeKey = UniqueKey();
  Key _bairroKey = UniqueKey();

  // Validation state
  bool _showError = false;

  @override
  void initState() {
    super.initState();
    _dio = widget.dio ?? Dio(BaseOptions(baseUrl: AppConstants.baseUrl));
    if (widget.initialEstadoId != null) {
      _loadEstadosAndRestore();
    } else {
      _loadEstados();
    }
  }

  Future<void> _loadEstadosAndRestore() async {
    // Load states first
    setState(() => _loadingEstados = true);
    try {
      final resp = await _dio.get('/location/estados');
      final list = (resp.data as Map<String, dynamic>)['estados'] as List;
      _estados = list
          .map((e) => _EstadoOption.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _estados = [];
    }
    if (mounted) setState(() => _loadingEstados = false);

    // Then restore initial state
    if (!mounted || widget.initialEstadoId == null) return;
    await _restoreInitialState();
  }

  @override
  void didUpdateWidget(AddressSelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If initial values changed after widget build, restore them
    if (widget.initialEstadoId != null &&
        (widget.initialEstadoId != oldWidget.initialEstadoId ||
            widget.initialCidadeId != oldWidget.initialCidadeId ||
            widget.initialBairroId != oldWidget.initialBairroId)) {
      _restoreInitialState();
    }
  }

  Future<void> _restoreInitialState() async {
    if (!mounted || widget.initialEstadoId == null) return;
    try {
      // Find and select estado
      _EstadoOption? estado;
      try {
        estado = _estados.firstWhere((e) => e.id == widget.initialEstadoId);
      } catch (_) {
        estado = _estados.isNotEmpty ? _estados.first : null;
      }

      if (estado == null) return;

      setState(() => _estado = estado);
      widget.onEstadoChanged?.call(estado.id);

      // Load cities for this state
      try {
        final resp = await _dio.get('/location/estados/${estado.id}/cidades');
        final list = (resp.data as Map<String, dynamic>)['cidades'] as List;
        final cidades = list
            .map((e) => _CidadeOption.fromJson(e as Map<String, dynamic>))
            .toList();
        if (!mounted) return;

        setState(() => _cidades = cidades);

        // If initialCidadeId provided, select it
        if (widget.initialCidadeId != null) {
          _CidadeOption? cidade;
          try {
            cidade = cidades.firstWhere((c) => c.id == widget.initialCidadeId);
          } catch (_) {
            cidade = cidades.isNotEmpty ? cidades.first : null;
          }

          if (cidade != null) {
            setState(() => _cidade = cidade);
            widget.onCidadeChanged?.call(cidade.id);

            // Load neighborhoods for this city
            try {
              final bResp = await _dio.get(
                '/location/cidades/${cidade.id}/bairros',
              );
              final bList =
                  (bResp.data as Map<String, dynamic>)['bairros'] as List;
              final bairros = bList
                  .map((e) => _BairroOption.fromJson(e as Map<String, dynamic>))
                  .toList();
              if (!mounted) return;

              setState(() => _bairros = bairros);

              // If initialBairroId provided, select it
              if (widget.initialBairroId != null) {
                _BairroOption? bairro;
                try {
                  bairro = bairros.firstWhere(
                    (b) => b.id == widget.initialBairroId,
                  );
                } catch (_) {
                  bairro = bairros.isNotEmpty ? bairros.first : null;
                }

                if (bairro != null) {
                  setState(() => _bairro = bairro);
                  widget.onChanged(bairro.id);
                }
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    } catch (_) {
      // Handle any errors during restore
    }
  }

  Future<void> _loadEstados() async {
    setState(() => _loadingEstados = true);
    try {
      final resp = await _dio.get('/location/estados');
      final list = (resp.data as Map<String, dynamic>)['estados'] as List;
      _estados = list
          .map((e) => _EstadoOption.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _estados = [];
    }
    if (mounted) setState(() => _loadingEstados = false);
  }

  Future<void> _onEstadoChanged(_EstadoOption? opt) async {
    setState(() {
      _estado = opt;
      _cidade = null;
      _bairro = null;
      _cidades = [];
      _bairros = [];
      _cidadeKey = UniqueKey();
      _bairroKey = UniqueKey();
      _loadingCidades = opt != null;
    });
    widget.onEstadoChanged?.call(opt?.id);
    widget.onChanged(null);
    if (opt == null) return;
    try {
      final resp = await _dio.get('/location/estados/${opt.id}/cidades');
      final list = (resp.data as Map<String, dynamic>)['cidades'] as List;
      _cidades = list
          .map((e) => _CidadeOption.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _cidades = [];
    }
    if (mounted) setState(() => _loadingCidades = false);
  }

  Future<void> _onCidadeChanged(_CidadeOption? opt) async {
    setState(() {
      _cidade = opt;
      _bairro = null;
      _bairros = [];
      _bairroKey = UniqueKey();
      _loadingBairros = opt != null;
    });
    widget.onCidadeChanged?.call(opt?.id);
    widget.onChanged(null);
    if (opt == null) return;
    try {
      final resp = await _dio.get('/location/cidades/${opt.id}/bairros');
      final list = (resp.data as Map<String, dynamic>)['bairros'] as List;
      _bairros = list
          .map((e) => _BairroOption.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      _bairros = [];
    }
    if (mounted) setState(() => _loadingBairros = false);
  }

  void _onBairroChanged(_BairroOption? opt) {
    setState(() {
      _bairro = opt;
      if (widget.isRequired) _showError = opt == null;
    });
    widget.onChanged(opt?.id);
  }

  Future<void> _createBairro(String name) async {
    if (_cidade == null) return;
    setState(() => _loadingBairros = true);
    try {
      final resp = await _dio.post(
        '/location/bairros',
        data: {'name': name.trim(), 'cidadeId': _cidade!.id},
      );
      if (mounted) {
        final newBairro = _BairroOption.fromJson(
          resp.data as Map<String, dynamic>,
        );
        setState(() {
          _bairros = [..._bairros, newBairro];
          _bairro = newBairro;
          _loadingBairros = false;
        });
        widget.onChanged(newBairro.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bairro "${name}" criado com sucesso!'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingBairros = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao criar bairro: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Called by parent Form on validate()
  String? _validate() {
    if (widget.isRequired && _bairro == null) {
      setState(() => _showError = true);
      return 'Selecione o bairro';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      validator: (_) => _validate(),
      builder: (field) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Estado ────────────────────────────────────────────────────
          _SearchableField<_EstadoOption>(
            key: const ValueKey('estado'),
            label: 'Estado${widget.isRequired ? ' *' : ''}',
            hint: _loadingEstados ? 'Carregando...' : 'Digite para filtrar...',
            icon: Icons.map_outlined,
            options: _estados,
            displayString: (e) => e.label,
            onSelected: (e) => _onEstadoChanged(e),
            selectedValue: _estado,
            loading: _loadingEstados,
          ),
          const SizedBox(height: AppSpacing.base),

          // ── Cidade ────────────────────────────────────────────────────
          _SearchableField<_CidadeOption>(
            key: _cidadeKey,
            label: 'Cidade${widget.isRequired ? ' *' : ''}',
            hint: _estado == null
                ? 'Selecione o estado primeiro'
                : _loadingCidades
                ? 'Carregando...'
                : 'Digite para filtrar...',
            icon: Icons.location_city_outlined,
            options: _cidades,
            displayString: (c) => c.name,
            onSelected: (c) => _onCidadeChanged(c),
            selectedValue: _cidade,
            enabled: _estado != null && !_loadingCidades,
            loading: _loadingCidades,
          ),
          const SizedBox(height: AppSpacing.base),

          // ── Bairro ────────────────────────────────────────────────────
          _SearchableField<_BairroOption>(
            key: _bairroKey,
            label: 'Bairro${widget.isRequired ? ' *' : ''}',
            hint: _cidade == null
                ? 'Selecione a cidade primeiro'
                : _loadingBairros
                ? 'Carregando...'
                : 'Digite para filtrar...',
            icon: Icons.location_on_outlined,
            options: _bairros,
            displayString: (b) => b.name,
            onSelected: (b) => _onBairroChanged(b),
            selectedValue: _bairro,
            enabled: _cidade != null && !_loadingBairros,
            loading: _loadingBairros,
            errorText: (field.errorText != null || _showError)
                ? (field.errorText ?? 'Selecione o bairro')
                : null,
            onCreateItem: _createBairro,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SearchableField — generic searchable/filterable dropdown using Autocomplete
// ─────────────────────────────────────────────────────────────────────────────

class _SearchableField<T extends Object> extends StatefulWidget {
  const _SearchableField({
    super.key,
    required this.label,
    required this.hint,
    required this.icon,
    required this.options,
    required this.displayString,
    required this.onSelected,
    this.enabled = true,
    this.loading = false,
    this.errorText,
    this.onCreateItem,
    this.selectedValue,
  });

  final String label;
  final String hint;
  final IconData icon;
  final List<T> options;
  final String Function(T) displayString;
  final void Function(T?) onSelected;
  final bool enabled;
  final bool loading;
  final String? errorText;
  final Future<void> Function(String)? onCreateItem;
  final T? selectedValue;

  @override
  State<_SearchableField<T>> createState() => _SearchableFieldState<T>();
}

class _SearchableFieldState<T extends Object>
    extends State<_SearchableField<T>> {
  bool _creatingItem = false;
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _updateTextFromSelection();
  }

  @override
  void didUpdateWidget(_SearchableField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedValue != oldWidget.selectedValue) {
      _updateTextFromSelection();
    }
  }

  void _updateTextFromSelection() {
    if (widget.selectedValue != null) {
      _textController.text = widget.displayString(widget.selectedValue as T);
    } else {
      _textController.clear();
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Autocomplete<T>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) return widget.options;
        final q = textEditingValue.text.toLowerCase();
        return widget.options.where(
          (o) => widget.displayString(o).toLowerCase().contains(q),
        );
      },
      displayStringForOption: widget.displayString,
      onSelected: widget.onSelected,
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        _textController = textController;
        return TextFormField(
          controller: textController,
          focusNode: focusNode,
          enabled: widget.enabled && !_creatingItem,
          onFieldSubmitted: (_) => onFieldSubmitted(),
          style: widget.enabled ? null : TextStyle(color: theme.disabledColor),
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            prefixIcon: Icon(widget.icon, size: 20),
            suffixIcon: _creatingItem || widget.loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : widget.enabled
                ? const Icon(Icons.arrow_drop_down, size: 20)
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            errorText: widget.errorText,
            errorMaxLines: 1,
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final query = _textController.text;
        final optionsList = options.toList();
        final hasCreateOption =
            widget.onCreateItem != null &&
            query.isNotEmpty &&
            optionsList.isEmpty;

        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: optionsList.length + (hasCreateOption ? 1 : 0),
                itemBuilder: (context, index) {
                  // Create option
                  if (hasCreateOption && index == optionsList.length) {
                    return ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.add,
                        size: 18,
                        color: AppColors.primary,
                      ),
                      title: Text(
                        'Criar "${query}"',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      onTap: () async {
                        setState(() => _creatingItem = true);
                        try {
                          await widget.onCreateItem!(query);
                          if (mounted) _textController.clear();
                        } finally {
                          if (mounted) setState(() => _creatingItem = false);
                        }
                      },
                    );
                  }

                  // Regular option
                  final option = optionsList.elementAt(index);
                  return ListTile(
                    dense: true,
                    title: Text(
                      widget.displayString(option),
                      style: AppTypography.bodyMedium,
                    ),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
