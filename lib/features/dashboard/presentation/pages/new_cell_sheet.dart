import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/models/leader_option.dart';
import '../utils/snackbar_helper.dart';
import '../../../../shared/widgets/address_selector.dart';
import 'leader_selector_page.dart';
import '../../../../shared/widgets/app_map_tiles.dart';

/// SRP: responsável apenas por renderizar o formulário de nova célula.
class NewCellSheet extends StatefulWidget {
  const NewCellSheet({super.key, required this.dio});
  final Dio dio;

  @override
  State<NewCellSheet> createState() => _NewCellSheetState();
}

class _NewCellSheetState extends State<NewCellSheet> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _timeCtrl = TextEditingController(text: '19:00');
  final _cepCtrl = TextEditingController();
  String _dayOfWeek = 'terca';
  String? _estadoId;
  String? _cidadeId;
  String? _bairroId;
  String? _cellTypeId;
  bool _isSaving = false;
  bool _isLoadingLeaders = true;
  bool _cepLoading = false;
  double? _latitude;
  double? _longitude;
  late final MapController _mapController;
  List<LeaderOption> _leaders = const [];
  LeaderOption? _selectedLeader;
  List<Map<String, dynamic>> _cellTypes = const [];

  static const _days = [
    ('segunda', 'Segunda-feira'),
    ('terca', 'Terça-feira'),
    ('quarta', 'Quarta-feira'),
    ('quinta', 'Quinta-feira'),
    ('sexta', 'Sexta-feira'),
    ('sabado', 'Sábado'),
    ('domingo', 'Domingo'),
  ];

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _loadLeaders();
    _loadCellTypes();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _timeCtrl.dispose();
    _cepCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  // ── CEP lookup ────────────────────────────────────────────────────────────

  Future<void> _lookupCep(String cep) async {
    final cleaned = cep.replaceAll(RegExp(r'\D'), '');
    if (cleaned.length != 8) return;

    setState(() => _cepLoading = true);
    try {
      final resp = await Dio().get('https://viacep.com.br/ws/$cleaned/json/');
      final data = resp.data as Map<String, dynamic>;
      if (data['erro'] == true) {
        setState(() => _cepLoading = false);
        return;
      }

      final logradouro = data['logradouro'] as String? ?? '';
      final bairroName = data['bairro'] as String? ?? '';
      final localidade = data['localidade'] as String? ?? '';
      final uf = data['uf'] as String? ?? '';

      String? foundEstadoId;
      String? foundCidadeId;
      String? foundBairroId;
      double? foundLat;
      double? foundLng;

      try {
        final estadosResp = await widget.dio.get('/location/estados');
        final estadosList =
            (estadosResp.data as Map<String, dynamic>)['estados'] as List;
        for (final e in estadosList) {
          final estado = e as Map<String, dynamic>;
          if ((estado['uf'] as String?)?.toUpperCase() == uf.toUpperCase()) {
            foundEstadoId = estado['id'] as String;
            break;
          }
        }
        if (foundEstadoId != null) {
          final cidadesResp = await widget.dio.get(
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
            final bairrosResp = await widget.dio.get(
              '/location/cidades/$foundCidadeId/bairros',
            );
            final bairrosList =
                (bairrosResp.data as Map<String, dynamic>)['bairros'] as List;
            for (final b in bairrosList) {
              final bairroOption = b as Map<String, dynamic>;
              if ((bairroOption['name'] as String?)?.trim().toLowerCase() ==
                  bairroName.trim().toLowerCase()) {
                foundBairroId = bairroOption['id'] as String;
                foundLat = (bairroOption['latitude'] as num?)?.toDouble();
                foundLng = (bairroOption['longitude'] as num?)?.toDouble();
                break;
              }
            }
          }
        }
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        if (logradouro.isNotEmpty) _addressCtrl.text = logradouro;
        _cepLoading = false;
        _estadoId = foundEstadoId;
        _cidadeId = foundCidadeId;
        _bairroId = foundBairroId;
        if (foundLat != null && foundLng != null) {
          _latitude = foundLat;
          _longitude = foundLng;
        }
      });

      if (foundLat != null && foundLng != null) {
        try {
          _mapController.move(LatLng(foundLat, foundLng), 15);
        } catch (_) {}
      } else {
        await _geocodeWithNominatim(cleaned, logradouro, localidade, uf);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _cepLoading = false);
    }
  }

  Future<void> _geocodeWithNominatim(
    String cep,
    String logradouro,
    String localidade,
    String uf,
  ) async {
    try {
      // Prefer CEP-based search for accuracy; fall back to address string
      final queryParams = cep.length == 8
          ? {
              'format': 'json',
              'postalcode': cep,
              'countrycodes': 'br',
              'limit': '1',
            }
          : {
              'format': 'json',
              'q': '$logradouro, $localidade, $uf, Brasil',
              'countrycodes': 'br',
              'limit': '1',
            };
      final resp = await Dio().get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: queryParams,
        options: Options(headers: {'User-Agent': 'SistemaIgrejaApp/1.0'}),
      );
      final results = resp.data as List;
      if (results.isNotEmpty && mounted) {
        final lat = double.tryParse(results[0]['lat'] as String? ?? '');
        final lng = double.tryParse(results[0]['lon'] as String? ?? '');
        if (lat != null && lng != null) {
          setState(() {
            _latitude = lat;
            _longitude = lng;
          });
          try {
            _mapController.move(LatLng(lat, lng), 15);
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  Future<void> _updateMapPosition() async {
    if (_latitude == null || _longitude == null) return;
    try {
      _mapController.move(LatLng(_latitude!, _longitude!), 15);
    } catch (_) {}
  }

  Future<void> _loadLeaders() async {
    setState(() => _isLoadingLeaders = true);
    try {
      final resp = await widget.dio.get('/users/leaders');
      final data = (resp.data as Map<String, dynamic>)['leaders'] as List;
      final leaders = data
          .map(
            (u) => LeaderOption(
              id: u['id'] as String,
              name: u['name'] as String,
              email: (u['email'] as String?) ?? '',
            ),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _leaders = leaders;
        _isLoadingLeaders = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingLeaders = false);
      showDashboardSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar líderes',
      );
    }
  }

  Future<void> _loadCellTypes() async {
    try {
      final resp = await widget.dio.get('/cell-types');
      final data =
          (resp.data as Map<String, dynamic>)['cellTypes'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _cellTypes = data.cast<Map<String, dynamic>>();
      });
    } catch (_) {
      // Non-fatal: cell types are optional
    }
  }

  Future<void> _openLeaderSelector() async {
    // Sem líder cadastrado a tela ainda abre: ela oferece "sem líder por
    // enquanto", que é como a primeira célula da igreja é criada.
    final selected = await Navigator.of(context).push<LeaderOption>(
      MaterialPageRoute(
        builder: (_) => LeaderSelectorPage(
          leaders: _leaders,
          initialId: _selectedLeader?.id,
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(
      () => _selectedLeader = selected.id.isEmpty ? null : selected,
    );
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final address = _addressCtrl.text.trim();
    final time = _timeCtrl.text.trim();
    final leaderId = _selectedLeader?.id ?? '';
    // Líder é opcional: a célula pode ficar sem líder e ser vinculada depois
    // pela tela de vínculos pendentes.
    if (name.isEmpty || address.isEmpty || _bairroId == null || time.isEmpty) {
      showDashboardSnackBar(
        context,
        'Preencha todos os campos obrigatórios',
        backgroundColor: AppColors.warning,
      );
      return;
    }
    setState(() => _isSaving = true);
    try {
      await widget.dio.post(
        '/cells',
        data: {
          'name': name,
          if (leaderId.isNotEmpty) 'leaderId': leaderId,
          'address': address,
          if (_estadoId != null) 'estadoId': _estadoId,
          if (_cidadeId != null) 'cidadeId': _cidadeId,
          if (_bairroId != null) 'bairroId': _bairroId,
          'dayOfWeek': _dayOfWeek,
          'time': time,
          if (_cellTypeId != null) 'cellTypeId': _cellTypeId,
          if (_latitude != null) 'latitude': _latitude,
          if (_longitude != null) 'longitude': _longitude,
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      showDashboardSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao criar célula',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              // O formulário é longo: no celular o usuário rolava e ficava sem
              // saída visível (arrastar o sheet pra baixo é a única outra).
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back),
                    tooltip: 'Voltar',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: AppSpacing.minTouchTarget,
                      minHeight: AppSpacing.minTouchTarget,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Nova Célula',
                      style: AppTypography.headlineSmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              AppTextField(
                controller: _nameCtrl,
                label: 'Nome da Célula *',
                hint: 'Ex: Célula Esperança',
                prefixIcon: Icons.groups_2_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              InkWell(
                onTap: _isLoadingLeaders ? null : _openLeaderSelector,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Líder',
                    prefixIcon: const Icon(Icons.person_search_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  child: _isLoadingLeaders
                      ? const Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: AppSpacing.sm),
                            Text('Carregando líderes...'),
                          ],
                        )
                      : Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedLeader?.name ??
                                    'Sem líder — definir depois',
                                style: AppTypography.bodyMedium,
                              ),
                            ),
                            const Icon(Icons.chevron_right),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.base),
              // ── CEP ──────────────────────────────────────────────────────
              Stack(
                children: [
                  AppTextField(
                    controller: _cepCtrl,
                    label: 'CEP (auto busca após 8 dígitos)',
                    hint: '00000-000',
                    prefixIcon: Icons.search_outlined,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    enabled: !_cepLoading,
                    inputFormatters: [
                      MaskTextInputFormatter(
                        mask: '#####-###',
                        filter: {'#': RegExp(r'[0-9]')},
                      ),
                    ],
                    onChanged: (v) {
                      final cleaned = v.replaceAll(RegExp(r'\D'), '');
                      if (cleaned.length == 8 && !_cepLoading) {
                        _lookupCep(cleaned);
                      }
                    },
                  ),
                  if (_cepLoading)
                    Positioned(
                      right: 50,
                      top: 0,
                      bottom: 0,
                      child: Center(
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
                ],
              ),
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _addressCtrl,
                label: 'Logradouro *',
                hint: 'Rua, número',
                prefixIcon: Icons.location_on_outlined,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppSpacing.base),
              AddressSelector(
                dio: widget.dio,
                initialEstadoId: _estadoId,
                initialCidadeId: _cidadeId,
                initialBairroId: _bairroId,
                onChanged: (id) {
                  setState(() => _bairroId = id);
                  _updateMapPosition();
                },
              ),

              // ── Mapa ──────────────────────────────────────────────────────
              const SizedBox(height: AppSpacing.base),
              Text('Localização no Mapa', style: AppTypography.titleSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _latitude != null
                    ? 'Toque no mapa para ajustar a posição'
                    : 'Informe um CEP ou toque no mapa para definir a localização',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _latitude != null
                          ? LatLng(_latitude!, _longitude!)
                          : const LatLng(-14.235, -51.925),
                      initialZoom: _latitude != null ? 15.0 : 4.0,
                      onTap: (_, point) => setState(() {
                        _latitude = point.latitude;
                        _longitude = point.longitude;
                      }),
                    ),
                    children: [
                      appTileLayer(),
                      if (_latitude != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(_latitude!, _longitude!),
                              child: const Icon(
                                Icons.location_on,
                                color: AppColors.primary,
                                size: 40,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
              if (_latitude != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Lat: ${_latitude!.toStringAsFixed(6)}, Lng: ${_longitude!.toStringAsFixed(6)}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.clear, size: 16),
                      label: const Text('Remover'),
                      onPressed: () => setState(() {
                        _latitude = null;
                        _longitude = null;
                      }),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppSpacing.base),
              AppTextField(
                controller: _timeCtrl,
                label: 'Horário *',
                hint: '19:00',
                prefixIcon: Icons.access_time_outlined,
                textInputAction: TextInputAction.done,
                keyboardType: TextInputType.datetime,
              ),
              const SizedBox(height: AppSpacing.base),
              if (_cellTypes.isNotEmpty) ...[
                Text(
                  'Tipo de Célula (opcional)',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.grey700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<String?>(
                  initialValue: _cellTypeId,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Sem tipo'),
                    ),
                    ..._cellTypes.map(
                      (t) => DropdownMenuItem(
                        value: t['id'] as String,
                        child: Text(t['name'] as String),
                      ),
                    ),
                  ],
                  onChanged: (v) => setState(() => _cellTypeId = v),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      borderSide: const BorderSide(color: AppColors.grey300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.base,
                      vertical: AppSpacing.md,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.base),
              ],
              Text(
                'Dia da semana',
                style: AppTypography.labelMedium.copyWith(
                  color: AppColors.grey700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String>(
                initialValue: _dayOfWeek,
                items: _days
                    .map(
                      (d) => DropdownMenuItem(value: d.$1, child: Text(d.$2)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _dayOfWeek = v!),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: const BorderSide(color: AppColors.grey300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.base,
                    vertical: AppSpacing.md,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              AppButton(
                label: _isSaving ? 'Salvando...' : 'Criar Célula',
                prefixIcon: Icons.add,
                onPressed: _isSaving ? null : _save,
              ),
              const SizedBox(height: AppSpacing.base),
            ],
          ),
        ),
      ),
    );
  }
}
