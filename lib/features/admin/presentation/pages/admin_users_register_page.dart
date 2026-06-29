import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../../../core/network/auth_storage.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/app_snackbar.dart';
import '../../../../shared/widgets/address_selector.dart';
import '../widgets/coordenacao_form_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

enum _UserType { leader, supervisor, coordinator }

class _Cell {
  _Cell({
    required this.id,
    required this.name,
    required this.leaderId,
    required this.neighborhood,
  });

  final String id;
  final String name;
  final String leaderId;
  final String neighborhood;

  factory _Cell.fromJson(Map<String, dynamic> j) => _Cell(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    leaderId: j['leaderId'] as String? ?? '',
    neighborhood: j['neighborhood'] as String? ?? '',
  );
}

class _Leader {
  _Leader({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;

  factory _Leader.fromJson(Map<String, dynamic> j) => _Leader(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    email: j['email'] as String? ?? '',
  );
}

class _Supervisor {
  _Supervisor({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;

  factory _Supervisor.fromJson(Map<String, dynamic> j) => _Supervisor(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    email: j['email'] as String? ?? '',
  );
}

class _Coordenacao {
  _Coordenacao({required this.id, required this.name, this.color});

  final String id;
  String name;
  final String? color;

  factory _Coordenacao.fromJson(Map<String, dynamic> j) => _Coordenacao(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    color: j['color'] as String?,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class AdminUsersRegisterPage extends StatefulWidget {
  const AdminUsersRegisterPage({super.key});

  @override
  State<AdminUsersRegisterPage> createState() => _AdminUsersRegisterPageState();
}

class _AdminUsersRegisterPageState extends State<AdminUsersRegisterPage> {
  late final Dio _dio;
  _UserType _selectedType = _UserType.leader;

  // Data
  List<_Cell> _cells = [];
  List<_Leader> _leaders = [];
  List<_Supervisor> _supervisors = [];
  List<_Coordenacao> _coordenacoes = [];
  bool _loadingData = true;

  // Form
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cepCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _complementoCtrl = TextEditingController();

  // Address state
  String? _bairroId;
  bool _cepLoading = false;
  String? _cepEstadoId;
  String? _cepCidadeId;
  String? _cepBairroId;

  // Selection
  final Set<String> _selectedCells = {};
  final Set<String> _selectedLeaders = {};
  final Set<String> _selectedSupervisors = {};
  String? _selectedCoordenacaoId;
  String _cellSearch = '';
  String _leaderSearch = '';
  String _supervisorSearch = '';

  // State
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _dio = DioClient(AuthStorage()).dio;
    _loadData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneCtrl.dispose();
    _cepCtrl.dispose();
    _addressCtrl.dispose();
    _numeroCtrl.dispose();
    _complementoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loadingData = true);
    try {
      final results = await Future.wait([
        _dio.get('/cells'),
        _dio.get('/users/leaders'),
        _dio.get('/users/supervisors'),
        _dio.get('/coordenacoes'),
      ]);

      if (!mounted) return;
      setState(() {
        _cells =
            ((results[0].data as Map<String, dynamic>)['cells'] as List?)
                ?.cast<Map<String, dynamic>>()
                .map(_Cell.fromJson)
                .toList() ??
            [];

        _leaders =
            ((results[1].data as Map<String, dynamic>)['leaders'] as List?)
                ?.cast<Map<String, dynamic>>()
                .map(_Leader.fromJson)
                .toList() ??
            [];

        _supervisors =
            ((results[2].data as Map<String, dynamic>)['supervisors'] as List?)
                ?.cast<Map<String, dynamic>>()
                .map(_Supervisor.fromJson)
                .toList() ??
            [];

        _coordenacoes =
            ((results[3].data as Map<String, dynamic>)['coordenacoes'] as List?)
                ?.cast<Map<String, dynamic>>()
                .map(_Coordenacao.fromJson)
                .toList() ??
            [];

        _loadingData = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingData = false);
      _showError('Erro ao carregar dados');
    }
  }

  /// Recarrega dados silenciosamente (sem mostrar loading spinner).
  /// Usado ao trocar de tipo para não destruir a árvore de widgets.
  Future<void> _refreshData() async {
    try {
      final results = await Future.wait([
        _dio.get('/cells'),
        _dio.get('/users/leaders'),
        _dio.get('/users/supervisors'),
        _dio.get('/coordenacoes'),
      ]);

      if (!mounted) return;
      setState(() {
        _cells =
            ((results[0].data as Map<String, dynamic>)['cells'] as List?)
                ?.cast<Map<String, dynamic>>()
                .map(_Cell.fromJson)
                .toList() ??
            [];

        _leaders =
            ((results[1].data as Map<String, dynamic>)['leaders'] as List?)
                ?.cast<Map<String, dynamic>>()
                .map(_Leader.fromJson)
                .toList() ??
            [];

        _supervisors =
            ((results[2].data as Map<String, dynamic>)['supervisors'] as List?)
                ?.cast<Map<String, dynamic>>()
                .map(_Supervisor.fromJson)
                .toList() ??
            [];

        _coordenacoes =
            ((results[3].data as Map<String, dynamic>)['coordenacoes'] as List?)
                ?.cast<Map<String, dynamic>>()
                .map(_Coordenacao.fromJson)
                .toList() ??
            [];
      });
    } catch (_) {
      // Ignora erros silenciosos no refresh
    }
  }

  void _showError(String message) => AppSnackbar.error(message);

  void _showSuccess(String message) => AppSnackbar.success(message);

  void _showCreateCoordenacaoSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => CoordenacaoFormSheet(dio: _dio, onSaved: _loadData),
    );
  }

  Future<void> _lookupCep(String cep) async {
    final cleaned = cep.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length != 8) return;

    setState(() => _cepLoading = true);
    try {
      // Step 1: Get address data from ViaCEP
      final resp = await Dio().get('https://viacep.com.br/ws/$cleaned/json/');
      final data = resp.data as Map<String, dynamic>;
      if (data['erro'] == true) {
        setState(() => _cepLoading = false);
        return;
      }

      final logradouro = data['logradouro'] as String? ?? '';
      final bairro = data['bairro'] as String? ?? '';
      final localidade = data['localidade'] as String? ?? '';
      final uf = data['uf'] as String? ?? '';

      try {
        // Step 2: Match Estado, Cidade e Bairro no backend
        final estadosResp = await _dio.get('/location/estados');
        final estadosList =
            (estadosResp.data as Map<String, dynamic>)['estados'] as List;
        String? foundEstadoId;
        String? foundCidadeId;
        String? foundBairroId;

        for (final e in estadosList) {
          final estado = e as Map<String, dynamic>;
          if ((estado['uf'] as String?)?.toUpperCase() == uf.toUpperCase()) {
            foundEstadoId = estado['id'] as String;
            break;
          }
        }

        if (foundEstadoId != null) {
          final cidadesResp = await _dio.get(
            '/location/estados/$foundEstadoId/cidades',
          );
          final cidadesList =
              (cidadesResp.data as Map<String, dynamic>)['cidades'] as List;
          for (final c in cidadesList) {
            final cidade = c as Map<String, dynamic>;
            if ((cidade['name'] as String?)?.trim().toLowerCase() ==
                localidade.trim().toLowerCase()) {
              foundCidadeId = cidade['id'] as String;
              break;
            }
          }

          if (foundCidadeId != null) {
            final bairrosResp = await _dio.get(
              '/location/cidades/$foundCidadeId/bairros',
            );
            final bairrosList =
                (bairrosResp.data as Map<String, dynamic>)['bairros'] as List;
            for (final b in bairrosList) {
              final bairroOption = b as Map<String, dynamic>;
              if ((bairroOption['name'] as String?)?.trim().toLowerCase() ==
                  bairro.trim().toLowerCase()) {
                foundBairroId = bairroOption['id'] as String;
                break;
              }
            }
          }
        }

        if (!mounted) return;
        setState(() {
          _addressCtrl.text = logradouro;
          _cepLoading = false;
          _cepEstadoId = foundEstadoId;
          _cepCidadeId = foundCidadeId;
          _cepBairroId = foundBairroId;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _addressCtrl.text = logradouro;
          _cepLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _cepLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate associations
    if (_selectedType == _UserType.leader && _selectedCells.isEmpty) {
      _showError('Selecione pelo menos uma célula');
      return;
    }
    if (_selectedType == _UserType.supervisor && _selectedLeaders.isEmpty) {
      _showError('Selecione pelo menos um líder');
      return;
    }
    if (_selectedType == _UserType.coordinator &&
        (_selectedLeaders.isEmpty || _selectedSupervisors.isEmpty)) {
      _showError('Selecione líderes e supervisores');
      return;
    }

    setState(() => _submitting = true);

    try {
      const roleMap = {
        _UserType.leader: 'LIDER',
        _UserType.supervisor: 'SUPERVISOR',
        _UserType.coordinator: 'COORDENADOR',
      };

      final Map<String, dynamic> payload = {
        'name': _nameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'password': _passwordCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'role': roleMap[_selectedType],
        if (_addressCtrl.text.trim().isNotEmpty)
          'address': _addressCtrl.text.trim(),
        if (_numeroCtrl.text.trim().isNotEmpty)
          'numero': _numeroCtrl.text.trim(),
        if (_complementoCtrl.text.trim().isNotEmpty)
          'complemento': _complementoCtrl.text.trim(),
        if (_bairroId != null) 'bairroId': _bairroId,
      };

      // Add associations
      if (_selectedType == _UserType.leader) {
        payload['cellIds'] = _selectedCells.toList();
      } else if (_selectedType == _UserType.supervisor) {
        payload['leaderIds'] = _selectedLeaders.toList();
      } else if (_selectedType == _UserType.coordinator) {
        payload['leaderIds'] = _selectedLeaders.toList();
        payload['supervisorIds'] = _selectedSupervisors.toList();
        if (_selectedCoordenacaoId != null) {
          payload['coordenacaoId'] = _selectedCoordenacaoId;
        }
      }

      await _dio.post('/users/create', data: payload);

      if (!mounted) return;
      setState(() => _submitting = false);

      _showSuccess('Cadastro realizado com sucesso!');
      _resetForm();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);

      final errorMessage = extractDioErrorMessage(
        e,
        fallback: 'Erro ao criar cadastro',
      );

      _showError(errorMessage);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameCtrl.clear();
    _emailCtrl.clear();
    _passwordCtrl.clear();
    _phoneCtrl.clear();
    _cepCtrl.clear();
    _addressCtrl.clear();
    _numeroCtrl.clear();
    _complementoCtrl.clear();
    setState(() {
      _bairroId = null;
      _cepEstadoId = null;
      _cepCidadeId = null;
      _cepBairroId = null;
      _selectedCells.clear();
      _selectedLeaders.clear();
      _selectedSupervisors.clear();
      _selectedCoordenacaoId = null;
      _cellSearch = '';
      _leaderSearch = '';
      _supervisorSearch = '';
    });
  }

  List<_Cell> get _filteredCells {
    if (_cellSearch.isEmpty) return _cells;
    final q = _cellSearch.toLowerCase();
    return _cells
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              c.neighborhood.toLowerCase().contains(q),
        )
        .toList();
  }

  List<_Leader> get _filteredLeaders {
    if (_leaderSearch.isEmpty) return _leaders;
    final q = _leaderSearch.toLowerCase();
    return _leaders
        .where(
          (l) =>
              l.name.toLowerCase().contains(q) ||
              l.email.toLowerCase().contains(q),
        )
        .toList();
  }

  List<_Supervisor> get _filteredSupervisors {
    if (_supervisorSearch.isEmpty) return _supervisors;
    final q = _supervisorSearch.toLowerCase();
    return _supervisors
        .where(
          (s) =>
              s.name.toLowerCase().contains(q) ||
              s.email.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Novo Cadastro',
              style: AppTypography.titleLarge.copyWith(
                color: AppColors.textOnPrimary,
              ),
            ),
            Text(
              'Líderes, Supervisores e Coordenadores',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textOnPrimary.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
      body: _loadingData
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Type selector
                  _SectionHeader(title: 'Tipo de Cadastro'),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _UserTypeCard(
                          label: 'Líder',
                          icon: Icons.person_outlined,
                          selected: _selectedType == _UserType.leader,
                          onTap: () => setState(() {
                            _selectedCells.clear();
                            _cellSearch = '';
                            _selectedType = _UserType.leader;
                            _refreshData();
                          }),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _UserTypeCard(
                          label: 'Supervisor',
                          icon: Icons.manage_accounts_outlined,
                          selected: _selectedType == _UserType.supervisor,
                          onTap: () => setState(() {
                            _selectedLeaders.clear();
                            _leaderSearch = '';
                            _selectedType = _UserType.supervisor;
                            _refreshData();
                          }),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: _UserTypeCard(
                          label: 'Coordenador',
                          icon: Icons.account_tree_outlined,
                          selected: _selectedType == _UserType.coordinator,
                          onTap: () => setState(() {
                            _selectedSupervisors.clear();
                            _supervisorSearch = '';
                            _selectedType = _UserType.coordinator;
                            _refreshData();
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionHeader(title: 'Informações Pessoais'),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nome Completo',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Nome é obrigatório'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _emailCtrl,
                          decoration: const InputDecoration(
                            labelText: 'E-mail',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'E-mail é obrigatório';
                            }
                            if (!RegExp(
                              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                            ).hasMatch(v)) {
                              return 'E-mail inválido';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _phoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Telefone',
                            prefixIcon: Icon(Icons.phone_outlined),
                            hintText: '(11) 99999-9999',
                          ),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            MaskTextInputFormatter(
                              mask: '(##) #####-####',
                              filter: {'#': RegExp(r'[0-9]')},
                            ),
                          ],
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Telefone é obrigatório'
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _passwordCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Senha Temporária *',
                            prefixIcon: Icon(Icons.lock_outlined),
                            hintText: 'Mínimo 6 caracteres',
                          ),
                          obscureText: true,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Senha é obrigatória';
                            }
                            if (v.length < 6) {
                              return 'Mínimo 6 caracteres';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.md),
                        const _SectionHeader(title: 'Dados de Endereço'),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _cepCtrl,
                          decoration: const InputDecoration(
                            labelText: 'CEP',
                            prefixIcon: Icon(Icons.mail_outlined),
                            hintText: '00000-000',
                          ),
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            MaskTextInputFormatter(
                              mask: '#####-###',
                              filter: {'#': RegExp(r'[0-9]')},
                            ),
                          ],
                          onChanged: _lookupCep,
                        ),
                        if (_cepLoading)
                          const Padding(
                            padding: EdgeInsets.only(top: AppSpacing.sm),
                            child: CircularProgressIndicator(),
                          ),
                        const SizedBox(height: AppSpacing.sm),
                        TextFormField(
                          controller: _addressCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Logradouro',
                            prefixIcon: Icon(Icons.location_on_outlined),
                          ),
                          readOnly: true,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _numeroCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Número',
                                  prefixIcon: Icon(Icons.home_outlined),
                                ),
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _complementoCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Complemento',
                                  prefixIcon: Icon(Icons.info_outlined),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AddressSelector(
                          onChanged: (bairroId) =>
                              setState(() => _bairroId = bairroId),
                          initialEstadoId: _cepEstadoId,
                          initialCidadeId: _cepCidadeId,
                          initialBairroId: _cepBairroId,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        // Associations
                        if (_selectedType == _UserType.leader)
                          _CellAssociation(
                            cells: _filteredCells,
                            selectedIds: _selectedCells,
                            onToggle: (id) => setState(() {
                              if (_selectedCells.contains(id)) {
                                _selectedCells.remove(id);
                              } else {
                                _selectedCells.add(id);
                              }
                            }),
                            searchQuery: _cellSearch,
                            onSearchChanged: (v) =>
                                setState(() => _cellSearch = v),
                          )
                        else if (_selectedType == _UserType.supervisor)
                          _LeaderAssociation(
                            leaders: _filteredLeaders,
                            selectedIds: _selectedLeaders,
                            onToggle: (id) => setState(() {
                              if (_selectedLeaders.contains(id)) {
                                _selectedLeaders.remove(id);
                              } else {
                                _selectedLeaders.add(id);
                              }
                            }),
                            searchQuery: _leaderSearch,
                            onSearchChanged: (v) =>
                                setState(() => _leaderSearch = v),
                          )
                        else if (_selectedType == _UserType.coordinator) ...[
                          _LeaderAssociation(
                            leaders: _filteredLeaders,
                            selectedIds: _selectedLeaders,
                            onToggle: (id) => setState(() {
                              if (_selectedLeaders.contains(id)) {
                                _selectedLeaders.remove(id);
                              } else {
                                _selectedLeaders.add(id);
                              }
                            }),
                            searchQuery: _leaderSearch,
                            onSearchChanged: (v) =>
                                setState(() => _leaderSearch = v),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _SupervisorAssociation(
                            supervisors: _filteredSupervisors,
                            selectedIds: _selectedSupervisors,
                            onToggle: (id) => setState(() {
                              if (_selectedSupervisors.contains(id)) {
                                _selectedSupervisors.remove(id);
                              } else {
                                _selectedSupervisors.add(id);
                              }
                            }),
                            searchQuery: _supervisorSearch,
                            onSearchChanged: (v) =>
                                setState(() => _supervisorSearch = v),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (_coordenacoes.isEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Coordenação',
                                  style: AppTypography.titleSmall.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Container(
                                  padding: const EdgeInsets.all(
                                    AppSpacing.base,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: AppColors.grey200,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Nenhuma coordenação cadastrada',
                                        style: AppTypography.bodyMedium
                                            .copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      SizedBox(
                                        width: double.infinity,
                                        child: FilledButton.icon(
                                          onPressed:
                                              _showCreateCoordenacaoSheet,
                                          icon: const Icon(Icons.add),
                                          label: const Text(
                                            'Criar Nova Coordenação',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Coordenação',
                                  style: AppTypography.titleSmall.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                ..._coordenacoes.map((c) {
                                  final selected =
                                      _selectedCoordenacaoId == c.id;
                                  return CheckboxListTile(
                                    dense: true,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    title: Text(
                                      c.name,
                                      style: AppTypography.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    value: selected,
                                    onChanged: (_) => setState(
                                      () => _selectedCoordenacaoId = c.id,
                                    ),
                                    activeColor: AppColors.primary,
                                  );
                                }),
                                const SizedBox(height: AppSpacing.sm),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: _showCreateCoordenacaoSheet,
                                    icon: const Icon(Icons.add),
                                    label: const Text('Criar Nova Coordenação'),
                                  ),
                                ),
                              ],
                            ),
                        ],
                        const SizedBox(height: AppSpacing.xl2),
                        // Buttons
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _submitting ? null : _submit,
                            icon: const Icon(Icons.check),
                            label: _submitting
                                ? const Text('Cadastrando...')
                                : const Text('Salvar Cadastro'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              disabledBackgroundColor: AppColors.grey200,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _resetForm,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Limpar Formulário'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) => Text(
    title,
    style: AppTypography.titleSmall.copyWith(
      color: AppColors.textPrimary,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _UserTypeCard extends StatelessWidget {
  const _UserTypeCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.base),
      decoration: BoxDecoration(
        color: selected ? AppColors.primarySurface : AppColors.surface,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.divider,
          width: selected ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 28,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(
              color: selected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _CellAssociation extends StatelessWidget {
  const _CellAssociation({
    required this.cells,
    required this.selectedIds,
    required this.onToggle,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  final List<_Cell> cells;
  final Set<String> selectedIds;
  final void Function(String) onToggle;
  final String searchQuery;
  final void Function(String) onSearchChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionHeader(
        title:
            'Associar Células (${selectedIds.length} selecionada${selectedIds.length == 1 ? '' : 's'})',
      ),
      const SizedBox(height: AppSpacing.sm),
      TextField(
        decoration: InputDecoration(
          hintText: 'Buscar célula…',
          prefixIcon: const Icon(Icons.search_outlined),
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          filled: true,
          fillColor: AppColors.grey100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: onSearchChanged,
      ),
      const SizedBox(height: AppSpacing.sm),
      if (cells.isEmpty)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text(
              'Nenhuma célula encontrada',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        )
      else
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: cells.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final cell = cells[i];
            final selected = selectedIds.contains(cell.id);
            return CheckboxListTile(
              title: Text(
                cell.name,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                cell.neighborhood,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              value: selected,
              onChanged: (_) => onToggle(cell.id),
              activeColor: AppColors.primary,
            );
          },
        ),
    ],
  );
}

class _LeaderAssociation extends StatelessWidget {
  const _LeaderAssociation({
    required this.leaders,
    required this.selectedIds,
    required this.onToggle,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  final List<_Leader> leaders;
  final Set<String> selectedIds;
  final void Function(String) onToggle;
  final String searchQuery;
  final void Function(String) onSearchChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionHeader(
        title:
            'Associar Líderes (${selectedIds.length} selecionado${selectedIds.length == 1 ? '' : 's'})',
      ),
      const SizedBox(height: AppSpacing.sm),
      TextField(
        decoration: InputDecoration(
          hintText: 'Buscar líder…',
          prefixIcon: const Icon(Icons.search_outlined),
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          filled: true,
          fillColor: AppColors.grey100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: onSearchChanged,
      ),
      const SizedBox(height: AppSpacing.sm),
      if (leaders.isEmpty)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text(
              'Nenhum líder encontrado',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        )
      else
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: leaders.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final leader = leaders[i];
            final selected = selectedIds.contains(leader.id);
            return CheckboxListTile(
              title: Text(
                leader.name,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                leader.email,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              value: selected,
              onChanged: (_) => onToggle(leader.id),
              activeColor: AppColors.primary,
            );
          },
        ),
    ],
  );
}

class _SupervisorAssociation extends StatelessWidget {
  const _SupervisorAssociation({
    required this.supervisors,
    required this.selectedIds,
    required this.onToggle,
    required this.searchQuery,
    required this.onSearchChanged,
  });

  final List<_Supervisor> supervisors;
  final Set<String> selectedIds;
  final void Function(String) onToggle;
  final String searchQuery;
  final void Function(String) onSearchChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionHeader(
        title:
            'Associar Supervisores (${selectedIds.length} selecionado${selectedIds.length == 1 ? '' : 's'})',
      ),
      const SizedBox(height: AppSpacing.sm),
      TextField(
        decoration: InputDecoration(
          hintText: 'Buscar supervisor…',
          prefixIcon: const Icon(Icons.search_outlined),
          contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          filled: true,
          fillColor: AppColors.grey100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: onSearchChanged,
      ),
      const SizedBox(height: AppSpacing.sm),
      if (supervisors.isEmpty)
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text(
              'Nenhum supervisor encontrado',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        )
      else
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: supervisors.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final supervisor = supervisors[i];
            final selected = selectedIds.contains(supervisor.id);
            return CheckboxListTile(
              title: Text(
                supervisor.name,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                supervisor.email,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              value: selected,
              onChanged: (_) => onToggle(supervisor.id),
              activeColor: AppColors.primary,
            );
          },
        ),
    ],
  );
}
