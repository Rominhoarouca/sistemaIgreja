import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_popup/flutter_map_marker_popup.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/address_selector.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data helpers
// ─────────────────────────────────────────────────────────────────────────────

class _CellOption {
  _CellOption({
    required this.id,
    required this.name,
    required this.leaderName,
    this.cellType = 'Célula',
    this.latitude,
    this.longitude,
    this.maxCapacity = 20,
    this.currentCount = 0,
  });

  final String id;
  final String name;
  final String leaderName;
  final String cellType;
  final double? latitude;
  final double? longitude;
  final int maxCapacity;
  final int currentCount;

  bool get isAvailable => currentCount < maxCapacity;
  int get availableSpots => maxCapacity - currentCount;

  String get display => '$name (Líder: $leaderName)';
}

const _maritalOptions = [
  'Solteiro(a)',
  'Casado(a)',
  'Divorciado(a)',
  'Viúvo(a)',
  'União estável',
];

const _interestOptions = [
  'Membro da igreja',
  'Procurando batismo',
  'Quero ter uma célula em casa',
  'Preciso de oração',
  'Outros',
];

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

/// Public visitor self-registration page — no login required.
class VisitorSelfRegisterPage extends StatefulWidget {
  const VisitorSelfRegisterPage({super.key});

  @override
  State<VisitorSelfRegisterPage> createState() =>
      _VisitorSelfRegisterPageState();
}

class _VisitorSelfRegisterPageState extends State<VisitorSelfRegisterPage> {
  // ── Dio (no auth) ──────────────────────────────────────────────────────────
  late final Dio _dio;

  // ── Form (wizard de 3 passos) ──────────────────────────────────────────────
  int _currentStep = 0;
  final _stepKeys = [
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
    GlobalKey<FormState>(),
  ];

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _cepCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _numeroCtrl = TextEditingController();
  final _complementoCtrl = TextEditingController();
  final _customCellCtrl = TextEditingController();
  final _otherInterestCtrl = TextEditingController();

  String? _bairroId;

  DateTime? _birthDate;
  String? _maritalStatus;
  bool _attendsCell = false;
  String? _selectedCellId; // null when "other"
  bool _customCellSelected = false;
  final Set<String> _interests = {};

  // ── Cell list state ────────────────────────────────────────────────────────
  bool _cellsLoading = true;
  List<_CellOption> _cells = [];

  // ── CEP Geolocation ────────────────────────────────────────────────────────
  bool _cepLoading = false;
  double? _cepLatitude;
  double? _cepLongitude;
  String? _cepEstadoId; // Estado ID from API
  String? _cepCidadeId; // Cidade ID from API
  String? _cepBairroId; // Bairro ID from API

  // ── Selected cell detailed info ────────────────────────────────────────────
  bool _selectedCellLoading = false;
  Map<String, dynamic>? _selectedCellDetails;

  // ── Submit state ───────────────────────────────────────────────────────────
  bool _submitting = false;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );
    _loadCells();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _cepCtrl.dispose();
    _addressCtrl.dispose();
    _numeroCtrl.dispose();
    _complementoCtrl.dispose();
    _customCellCtrl.dispose();
    _otherInterestCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCells() async {
    try {
      final resp = await _dio.get('/cells/public');
      final list = ((resp.data as Map<String, dynamic>)['cells'] as List)
          .cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() {
        _cells = list
            .map(
              (c) => _CellOption(
                id: c['id'] as String,
                name: c['name'] as String? ?? '',
                leaderName: c['leaderName'] as String? ?? 'Sem líder',
                cellType: c['cellType'] as String? ?? 'Célula',
                latitude: (c['latitude'] as num?)?.toDouble(),
                longitude: (c['longitude'] as num?)?.toDouble(),
                maxCapacity: (c['maxCapacity'] as num?)?.toInt() ?? 20,
                currentCount: (c['currentCount'] as num?)?.toInt() ?? 0,
              ),
            )
            .toList();
        _cellsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cellsLoading = false);
    }
  }

  Future<void> _pickBirthDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      helpText: 'Data de Nascimento',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _lookupCep(String cep) async {
    final cleaned = cep.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length != 8) return;

    setState(() => _cepLoading = true);
    try {
      // Step 1: Get address data from ViaCEP only
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
        // Step 2: Try to match Estado, Cidade e Bairro in the backend
        // First, find the estado by UF
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

        // If found estado, search for cidade
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

          // If found cidade, search for bairro
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

        // Geocode to get latitude/longitude and load nearby cells
        _geocodeCep(logradouro, localidade, uf);
      } catch (e) {
        // If location API fails, just set address
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

  void _onCepChanged(String value) {
    final cleaned = value.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length == 8 && !_cepLoading) {
      _lookupCep(cleaned);
    }
  }

  void _onNumeroChanged(String value) {
    // Trigger map update when number changes (if cell selected)
    if (_attendsCell &&
        _selectedCellId != null &&
        _selectedCellDetails != null) {
      setState(() {}); // Trigger rebuild to update map
    }
  }

  Future<void> _loadSelectedCellDetails(String cellId) async {
    setState(() => _selectedCellLoading = true);
    try {
      final resp = await _dio.get('/cells/$cellId');
      final cellData = resp.data as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _selectedCellDetails = cellData;
        _selectedCellLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _selectedCellDetails = null;
        _selectedCellLoading = false;
      });
    }
  }

  Future<void> _geocodeCep(
    String logradouro,
    String localidade,
    String uf,
  ) async {
    try {
      // Use Nominatim to get coordinates based on CEP
      final query = '$logradouro, $localidade, $uf, Brasil';
      final resp = await Dio().get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'format': 'json',
          'q': query,
          'countrycodes': 'br',
          'limit': '1',
        },
        options: Options(headers: {'User-Agent': 'SistemaIgrejaApp/1.0'}),
      );
      final results = resp.data as List;
      if (results.isNotEmpty && mounted) {
        final lat = double.tryParse(results[0]['lat'] as String? ?? '');
        final lng = double.tryParse(results[0]['lon'] as String? ?? '');
        if (lat != null && lng != null) {
          setState(() {
            _cepLatitude = lat;
            _cepLongitude = lng;
          });
        }
      }
    } catch (_) {}
  }

  // Future<void> _loadSelectedCellDetails was here

  Future<void> _submit() async {
    if (!(_stepKeys[_currentStep].currentState?.validate() ?? false)) return;

    // Extra validation: cell selection when attends
    if (_attendsCell && !_customCellSelected && _selectedCellId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecione a célula que você frequenta.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    if (_attendsCell &&
        _customCellSelected &&
        _customCellCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe o nome da célula.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final interests = _interests.toList();
      final otherText = _otherInterestCtrl.text.trim();
      if (interests.contains('Outros') && otherText.isNotEmpty) {
        interests.remove('Outros');
        interests.add('Outros: $otherText');
      } else if (interests.contains('Outros')) {
        interests.remove('Outros');
      }

      final body = <String, dynamic>{
        'name': _nameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        if (_numeroCtrl.text.trim().isNotEmpty)
          'numero': _numeroCtrl.text.trim(),
        if (_complementoCtrl.text.trim().isNotEmpty)
          'complemento': _complementoCtrl.text.trim(),
        if (_bairroId != null) 'bairroId': _bairroId,
        'interests': interests,
        if (_birthDate != null) 'birthDate': _birthDate!.toIso8601String(),
        if (_maritalStatus != null) 'maritalStatus': _maritalStatus,
        if (_attendsCell && !_customCellSelected && _selectedCellId != null)
          'cellId': _selectedCellId,
        if (_attendsCell &&
            _customCellSelected &&
            _customCellCtrl.text.trim().isNotEmpty)
          'customCellName': _customCellCtrl.text.trim(),
      };

      await _dio.post('/visitors/self-register', data: body);
      if (!mounted) return;
      setState(() => _success = true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      final msg =
          e.response?.data?['error']?['message'] as String? ??
          'Erro ao enviar cadastro. Tente novamente.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error),
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build — wizard de 3 passos (design_handoff_sistema_igreja)
  // ─────────────────────────────────────────────────────────────────────────

  static const _stepTitles = ['Dados pessoais', 'Endereço', 'Sobre você'];

  @override
  Widget build(BuildContext context) {
    if (_success) return _SuccessScreen();
    final isWide = MediaQuery.sizeOf(context).width >= 720.0;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(isWide),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWide
                        ? AppSpacing.xl2
                        : AppSpacing.pagePaddingH,
                    vertical: AppSpacing.lg,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: _buildCard(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isWide) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pagePaddingH,
        AppSpacing.lg,
        AppSpacing.pagePaddingH,
        AppSpacing.sm,
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  const Icon(Icons.church_outlined, color: AppColors.gold),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Que alegria receber você!',
            textAlign: TextAlign.center,
            style: (isWide
                    ? AppTypography.headlineSmall
                    : AppTypography.titleLarge)
                .copyWith(color: AppColors.white),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Preencha seus dados para se conectar à nossa comunidade.',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.white.withValues(alpha: .7),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          _buildStepper(isWide),
        ],
      ),
    );
  }

  /// Stepper de 3 passos — dot dourado ativo; barra de progresso no mobile.
  Widget _buildStepper(bool isWide) {
    if (!isWide) {
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            child: LinearProgressIndicator(
              value: (_currentStep + 1) / 3,
              minHeight: 6,
              backgroundColor: AppColors.white.withValues(alpha: .15),
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Passo ${_currentStep + 1} de 3 · ${_stepTitles[_currentStep]}',
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.white.withValues(alpha: .75),
            ),
          ),
        ],
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0)
            Container(
              width: 44,
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              color: i <= _currentStep
                  ? AppColors.gold
                  : AppColors.white.withValues(alpha: .2),
            ),
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i <= _currentStep
                      ? AppColors.gold
                      : AppColors.white.withValues(alpha: .12),
                  border: Border.all(
                    color: i <= _currentStep
                        ? AppColors.gold
                        : AppColors.white.withValues(alpha: .3),
                  ),
                ),
                child: i < _currentStep
                    ? const Icon(Icons.check, size: 14, color: AppColors.navy900)
                    : Text(
                        '${i + 1}',
                        style: AppTypography.labelSmall.copyWith(
                          color: i <= _currentStep
                              ? AppColors.navy900
                              : AppColors.white.withValues(alpha: .7),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _stepTitles[i],
                style: AppTypography.labelMedium.copyWith(
                  color: i == _currentStep
                      ? AppColors.white
                      : AppColors.white.withValues(alpha: .55),
                  fontWeight: i == _currentStep
                      ? FontWeight.w600
                      : FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCard(BuildContext context) {
    final steps = [_buildStepPersonal(), _buildStepAddress(), _buildStepAbout()];
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.radiusXl2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Form(
          key: _stepKeys[_currentStep],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(
                  key: ValueKey(_currentStep),
                  child: steps[_currentStep],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: SizedBox(
                        height: AppSpacing.buttonHeightMd,
                        child: OutlinedButton(
                          onPressed: _submitting ? null : _previousStep,
                          child: const Text('Voltar'),
                        ),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 2,
                    child: SizedBox(
                      height: AppSpacing.buttonHeightMd,
                      child: _currentStep < 2
                          ? FilledButton(
                              onPressed: _nextStep,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: AppColors.white,
                                textStyle: AppTypography.buttonLabel,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.radiusMd,
                                  ),
                                ),
                              ),
                              child: const Text('Continuar'),
                            )
                          : AppButton(
                              label: 'Concluir',
                              isLoading: _submitting,
                              onPressed: _submit,
                            ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _nextStep() {
    if (!(_stepKeys[_currentStep].currentState?.validate() ?? false)) return;
    if (_currentStep == 0 && _birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Informe sua data de nascimento.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }
    setState(() => _currentStep++);
  }

  void _previousStep() => setState(() => _currentStep--);

  // ── Passo 1 · Dados pessoais ───────────────────────────────────────────────

  Widget _buildStepPersonal() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Dados Pessoais', Icons.person_outline),
        const SizedBox(height: AppSpacing.base),
        AppTextField(
          controller: _nameCtrl,
          label: 'Nome completo *',
          hint: 'Ex: João da Silva',
          prefixIcon: Icons.person_outline,
          textInputAction: TextInputAction.next,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
        ),
        const SizedBox(height: AppSpacing.fieldGap),
        AppTextField(
          controller: _phoneCtrl,
          label: 'Telefone / WhatsApp *',
          hint: '(00) 00000-0000',
          prefixIcon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            MaskTextInputFormatter(
              mask: '(##) #####-####',
              filter: {'#': RegExp(r'[0-9]')},
            ),
          ],
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Campo obrigatório';
            final cleaned = v.replaceAll(RegExp(r'\D'), '');
            return cleaned.length < 10 ? 'Telefone inválido' : null;
          },
        ),
        const SizedBox(height: AppSpacing.fieldGap),
        _DatePickerField(
          label: 'Data de Nascimento *',
          value: _birthDate,
          onTap: _pickBirthDate,
          validator: () => _birthDate == null ? 'Campo obrigatório' : null,
        ),
        const SizedBox(height: AppSpacing.fieldGap),
        _DropdownField<String>(
          label: 'Estado Civil (opcional)',
          value: _maritalStatus,
          hint: 'Selecione',
          items: _maritalOptions,
          itemLabel: (v) => v,
          onChanged: (v) => setState(() => _maritalStatus = v),
        ),
      ],
    );
  }

  // ── Passo 2 · Endereço ─────────────────────────────────────────────────────

  Widget _buildStepAddress() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Endereço', Icons.location_on_outlined),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Seu endereço nos ajuda a localizar células próximas de você.',
          style: AppTypography.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.base),
        Stack(
          children: [
            AppTextField(
              controller: _cepCtrl,
              label: 'CEP (busca automática)',
              hint: '00000-000',
              prefixIcon: Icons.location_on_outlined,
              suffixIcon: _cepLoading ? null : Icons.search_outlined,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              onChanged: _onCepChanged,
              inputFormatters: [
                MaskTextInputFormatter(
                  mask: '#####-###',
                  filter: {'#': RegExp(r'[0-9]')},
                ),
              ],
              enabled: !_cepLoading,
            ),
            if (_cepLoading)
              const Positioned(
                right: 50,
                top: 0,
                bottom: 0,
                child: Center(
                  child: Tooltip(
                    message: 'Buscando CEP...',
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.fieldGap),
        AppTextField(
          controller: _addressCtrl,
          label: 'Logradouro *',
          hint: 'Rua, avenida, etc',
          prefixIcon: Icons.home_outlined,
          textInputAction: TextInputAction.next,
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Campo obrigatório' : null,
        ),
        const SizedBox(height: AppSpacing.fieldGap),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: AppTextField(
                controller: _numeroCtrl,
                label: 'Número *',
                hint: 'Ex: 123',
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.next,
                onChanged: _onNumeroChanged,
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Campo obrigatório'
                    : null,
              ),
            ),
            const SizedBox(width: AppSpacing.fieldGap),
            Expanded(
              flex: 3,
              child: AppTextField(
                controller: _complementoCtrl,
                label: 'Complemento',
                hint: 'Apto, bloco, etc',
                textInputAction: TextInputAction.next,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.fieldGap),
        AddressSelector(
          onChanged: (id) {
            setState(() => _bairroId = id);
          },
          initialEstadoId: _cepEstadoId,
          initialCidadeId: _cepCidadeId,
          initialBairroId: _cepBairroId,
        ),
      ],
    );
  }

  // ── Passo 3 · Sobre você ───────────────────────────────────────────────────

  Widget _buildStepAbout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Sobre Você', Icons.info_outline),
        const SizedBox(height: AppSpacing.base),
        _buildCellSwitch(),
        if (_attendsCell) ...[
          const SizedBox(height: AppSpacing.sm),
          _CellSelector(
            cells: _cells,
            loading: _cellsLoading,
            selectedCellId: _selectedCellId,
            customCellSelected: _customCellSelected,
            customCellCtrl: _customCellCtrl,
            cepLatitude: _cepLatitude,
            cepLongitude: _cepLongitude,
            selectedCellDetails: _selectedCellDetails,
            selectedCellLoading: _selectedCellLoading,
            onCellSelected: (id, isCustom) {
              setState(() {
                _selectedCellId = isCustom ? null : id;
                _customCellSelected = isCustom;
                if (!isCustom) {
                  _customCellCtrl.clear();
                  if (id != null) _loadSelectedCellDetails(id);
                } else {
                  _selectedCellDetails = null;
                }
              });
            },
          ),
        ],
        const SizedBox(height: AppSpacing.base),
        const Divider(),
        const SizedBox(height: AppSpacing.base),
        _sectionHeader('Como posso ajudar você?', Icons.favorite_outline),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Selecione todas as opções que se aplicam',
          style: AppTypography.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: _interestOptions
              .map(
                (opt) => FilterChip(
                  label: Text(opt),
                  selected: _interests.contains(opt),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      _interests.add(opt);
                    } else {
                      _interests.remove(opt);
                      if (opt == 'Outros') _otherInterestCtrl.clear();
                    }
                  }),
                  showCheckmark: false,
                  side: BorderSide(
                    color: _interests.contains(opt)
                        ? AppColors.primary
                        : Theme.of(context).colorScheme.outlineVariant,
                    width: _interests.contains(opt) ? 1.5 : 1,
                  ),
                  labelStyle: AppTypography.bodySmall.copyWith(
                    color: _interests.contains(opt)
                        ? AppColors.primary
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: _interests.contains(opt)
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              )
              .toList(),
        ),
        if (_interests.contains('Outros')) ...[
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _otherInterestCtrl,
            label: 'Especifique outros interesses',
            hint: 'Descreva brevemente',
            maxLines: 2,
            prefixIcon: Icons.edit_outlined,
          ),
        ],
      ],
    );
  }

  Widget _buildCellSwitch() {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          const Icon(Icons.home_outlined, color: AppColors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Deseja participar de alguma célula?',
              style: AppTypography.bodyMedium,
            ),
          ),
          Switch(
            value: _attendsCell,
            onChanged: (v) => setState(() {
              _attendsCell = v;
              if (!v) {
                _selectedCellId = null;
                _customCellSelected = false;
                _customCellCtrl.clear();
              }
            }),
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(title, style: AppTypography.titleMedium),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Cell Selector widget
// ─────────────────────────────────────────────────────────────────────────────

class _CellSelector extends StatefulWidget {
  const _CellSelector({
    required this.cells,
    required this.loading,
    required this.selectedCellId,
    required this.customCellSelected,
    required this.customCellCtrl,
    required this.onCellSelected,
    this.cepLatitude,
    this.cepLongitude,
    this.selectedCellDetails,
    this.selectedCellLoading = false,
  });

  final List<_CellOption> cells;
  final bool loading;
  final String? selectedCellId;
  final bool customCellSelected;
  final TextEditingController customCellCtrl;
  final void Function(String? id, bool isCustom) onCellSelected;
  final double? cepLatitude;
  final double? cepLongitude;
  final Map<String, dynamic>? selectedCellDetails;
  final bool selectedCellLoading;

  @override
  State<_CellSelector> createState() => _CellSelectorState();
}

class _CellSelectorState extends State<_CellSelector> {
  String? _selectedCellType;
  bool _showOnlyAvailable = false;
  final PopupController _popupController = PopupController();

  @override
  void dispose() {
    _popupController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.sm),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Get unique cell types
    final cellTypes = widget.cells.map((c) => c.cellType).toSet().toList();

    // Filter cells by type and availability
    var filteredCells = _selectedCellType == null
        ? widget.cells
        : widget.cells.where((c) => c.cellType == _selectedCellType).toList();

    if (_showOnlyAvailable) {
      filteredCells = filteredCells.where((c) => c.isAvailable).toList();
    }

    final String? currentValue = widget.customCellSelected
        ? '__custom__'
        : widget.selectedCellId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cell type filter
        if (cellTypes.length > 1) ...[
          Text('Filtrar por tipo de célula:', style: AppTypography.bodySmall),
          const SizedBox(height: AppSpacing.xs),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  label: const Text('Todos'),
                  selected: _selectedCellType == null,
                  onSelected: (_) => setState(() => _selectedCellType = null),
                  selectedColor: AppColors.primary.withValues(alpha: 0.15),
                  checkmarkColor: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.xs),
                ...cellTypes.map(
                  (type) => Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.xs),
                    child: FilterChip(
                      label: Text(type),
                      selected: _selectedCellType == type,
                      onSelected: (_) =>
                          setState(() => _selectedCellType = type),
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      checkmarkColor: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),
        ],

        // Filter: Show only available cells
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Mostrar apenas células com vagas',
                  style: AppTypography.bodySmall,
                ),
              ),
              Switch(
                value: _showOnlyAvailable,
                onChanged: (v) => setState(() => _showOnlyAvailable = v),
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.base),

        // List view (cell selector)
        _buildListView(filteredCells, currentValue),
        const SizedBox(height: AppSpacing.base),

        // Map view (always visible)
        _buildMapView(filteredCells),
      ],
    );
  }

  Widget _buildMapView(List<_CellOption> filteredCells) {
    // If a cell is selected and we have its details, show only that cell
    if (widget.selectedCellId != null && widget.selectedCellDetails != null) {
      final cellLat = (widget.selectedCellDetails!['latitude'] as num?)
          ?.toDouble();
      final cellLng = (widget.selectedCellDetails!['longitude'] as num?)
          ?.toDouble();

      if (cellLat == null || cellLng == null) {
        return AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            'Localização da célula não disponível',
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        );
      }

      final cellName =
          widget.selectedCellDetails!['name'] as String? ?? 'Célula';
      final leaderName =
          widget.selectedCellDetails!['leaderName'] as String? ?? 'Sem líder';
      final cellTime = widget.selectedCellDetails!['time'] as String? ?? '';
      final cellAddress =
          widget.selectedCellDetails!['address'] as String? ?? '';

      return SizedBox(
        height: 350,
        child: FlutterMap(
          key: ValueKey<String>('map_${cellLat}_$cellLng'),
          options: MapOptions(
            initialCenter: LatLng(cellLat, cellLng),
            initialZoom: 15,
            maxZoom: 18,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.app',
            ),
            PopupMarkerLayer(
              options: PopupMarkerLayerOptions(
                popupController: _popupController,
                markers: [
                  Marker(
                    key: ValueKey(widget.selectedCellId!),
                    point: LatLng(cellLat, cellLng),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(50),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(8),
                      child: const Icon(
                        Icons.groups,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ],
                popupDisplayOptions: PopupDisplayOptions(
                  builder: (BuildContext ctx, Marker marker) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cellName,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs2),
                          _PopupInfoRow(label: 'Líder:', value: leaderName),
                          const SizedBox(height: AppSpacing.xs2),
                          _PopupInfoRow(
                            label: 'Horário:',
                            value: cellTime.isEmpty
                                ? 'Não informado'
                                : cellTime,
                          ),
                          const SizedBox(height: AppSpacing.xs2),
                          _PopupInfoRow(
                            label: 'Endereço:',
                            value: cellAddress.isEmpty
                                ? 'Não informado'
                                : cellAddress,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Otherwise, show all cells
    final validCells = filteredCells
        .where((c) => c.latitude != null && c.longitude != null)
        .toList();

    if (validCells.isEmpty) {
      return AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          'Nenhuma célula com localização disponível',
          textAlign: TextAlign.center,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    // Use CEP location as center if available, otherwise use São Paulo
    final centerLat = widget.cepLatitude ?? -23.5505;
    final centerLng = widget.cepLongitude ?? -46.6333;

    return SizedBox(
      height: 300,
      child: FlutterMap(
        key: ValueKey<String>('map_${centerLat}_$centerLng'),
        options: MapOptions(
          initialCenter: LatLng(centerLat, centerLng),
          initialZoom: 13,
          maxZoom: 18,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.app',
          ),
          PopupMarkerLayer(
            options: PopupMarkerLayerOptions(
              popupController: _popupController,
              markers: validCells
                  .map(
                    (cell) => Marker(
                      key: ValueKey(cell.id),
                      point: LatLng(cell.latitude!, cell.longitude!),
                      child: Icon(
                        Icons.location_on,
                        color: widget.selectedCellId == cell.id
                            ? AppColors.error
                            : AppColors.primary,
                        size: 40,
                      ),
                    ),
                  )
                  .toList(),
              popupDisplayOptions: PopupDisplayOptions(
                builder: (BuildContext ctx, Marker marker) {
                  final cellId = (marker.key as ValueKey<String>).value;
                  final cell = validCells.firstWhere((c) => c.id == cellId);
                  final isSelected = widget.selectedCellId == cellId;
                  final leaderName = isSelected
                      ? (widget.selectedCellDetails?['leaderName']
                                as String?) ??
                            cell.leaderName
                      : cell.leaderName;
                  final cellTime = isSelected
                      ? (widget.selectedCellDetails?['time'] as String?) ??
                            'Selecione para ver detalhes'
                      : 'Selecione para ver detalhes';
                  final cellAddress = isSelected
                      ? (widget.selectedCellDetails?['address'] as String?) ??
                            'Selecione para ver detalhes'
                      : 'Selecione para ver detalhes';

                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            cell.name,
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs2),
                          _PopupInfoRow(label: 'Líder:', value: leaderName),
                          const SizedBox(height: AppSpacing.xs2),
                          _PopupInfoRow(label: 'Horário:', value: cellTime),
                          const SizedBox(height: AppSpacing.xs2),
                          _PopupInfoRow(label: 'Endereço:', value: cellAddress),
                          const SizedBox(height: AppSpacing.xs),
                          AppButton(
                            label: isSelected ? 'Selecionada ✓' : 'Selecionar',
                            variant: isSelected
                                ? AppButtonVariant.outline
                                : AppButtonVariant.primary,
                            isFullWidth: false,
                            onPressed: () {
                              widget.onCellSelected(cell.id, false);
                              _popupController.hideAllPopups();
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(List<_CellOption> filteredCells, String? currentValue) {
    return _DropdownField<String>(
      label: 'Qual celula voce frequenta? *',
      value: currentValue,
      hint: 'Selecione uma celula',
      items: [...filteredCells.map((c) => c.id), '__custom__'],
      itemLabel: (v) {
        if (v == '__custom__') return 'Outra (nao esta na lista)';
        final cell = filteredCells.firstWhere((c) => c.id == v);
        return cell.display;
      },
      onChanged: (v) {
        if (v == '__custom__') {
          widget.onCellSelected(null, true);
        } else {
          widget.onCellSelected(v, false);
        }
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PopupInfoRow extends StatelessWidget {
  const _PopupInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Text(
            value,
            style: AppTypography.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.validator,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final String? Function() validator;

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd/MM/yyyy');
    return FormField<DateTime>(
      initialValue: value,
      validator: (_) => validator(),
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onTap,
              child: AbsorbPointer(
                child: AppTextField(
                  controller: TextEditingController(
                    text: value != null ? fmt.format(value!) : '',
                  ),
                  label: label,
                  hint: 'DD/MM/AAAA',
                  prefixIcon: Icons.cake_outlined,
                  readOnly: true,
                ),
              ),
            ),
            if (field.errorText != null) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  field.errorText!,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.hint,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final String hint;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surface,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            border: Border.all(
              color: isDark ? AppColors.dividerDark : AppColors.divider,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isExpanded: true,
              value: value,
              hint: Text(
                hint,
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              items: items
                  .map(
                    (item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(
                        itemLabel(item),
                        style: AppTypography.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.base),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Success Screen
// ─────────────────────────────────────────────────────────────────────────────

class _SuccessScreen extends StatelessWidget {
  const _SuccessScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.success,
                    size: 48,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Cadastro Enviado!',
                  style: AppTypography.headlineSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Obrigado por se cadastrar. Em breve alguém\nda nossa equipe entrará em contato.',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl2),
                AppButton(
                  label: 'Fechar',
                  variant: AppButtonVariant.outline,
                  isFullWidth: false,
                  prefixIcon: Icons.close,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
