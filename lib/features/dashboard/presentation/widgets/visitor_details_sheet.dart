import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../utils/snackbar_helper.dart';
import '../widgets/detail_row.dart';
import '../widgets/visitor_widgets.dart';
import '../../../../injection/injection.dart';

/// SRP: responsável apenas por exibir os detalhes completos de um visitante.
class VisitorDetailsSheet extends StatelessWidget {
  const VisitorDetailsSheet({
    super.key,
    required this.visitor,
    this.panel = false,
    this.onChanged,
  });

  final Map<String, dynamic> visitor;

  /// Quando true, renderiza como painel lateral fixo (desktop) em vez de
  /// bottom-sheet arrastável.
  final bool panel;

  /// Chamado quando uma ação aqui dentro muda o visitante (ex.: direcionado
  /// para uma célula) — o chamador decide se isso significa recarregar a
  /// lista, fechar o painel, etc.
  final VoidCallback? onChanged;

  static String _textOrDash(Object? v) {
    final value = (v ?? '').toString().trim();
    return value.isEmpty ? 'Não informado' : value;
  }

  static String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Não informado';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}/'
          '${date.year}';
    } catch (_) {
      return 'Data inválida';
    }
  }

  static int? _calculateAge(String? birthDateStr) {
    if (birthDateStr == null || birthDateStr.isEmpty) return null;
    try {
      final birthDate = DateTime.parse(birthDateStr);
      final today = DateTime.now();
      int age = today.year - birthDate.year;
      if (today.month < birthDate.month ||
          (today.month == birthDate.month && today.day < birthDate.day)) {
        age--;
      }
      return age;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = _textOrDash(visitor['name']);
    final status = _textOrDash(visitor['status']);
    final createdAt = DateTime.tryParse(
      (visitor['createdAt'] as String?) ?? '',
    );
    final age = _calculateAge(visitor['birthDate'] as String?);

    String relativeTime() {
      if (createdAt == null) return 'Sem data';
      final diff = DateTime.now().difference(createdAt);
      if (diff.inDays == 0) return 'hoje';
      if (diff.inDays == 1) return 'há 1 dia';
      if (diff.inDays < 7) return 'há ${diff.inDays} dias';
      if (diff.inDays < 14) return 'há 1 sem.';
      return 'há ${(diff.inDays / 7).round()} sem.';
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AppAvatar(
              initials: name.split(' ').map((e) => e[0]).take(2).join(),
              size: 56,
            ),
            const SizedBox(width: AppSpacing.base),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: AppTypography.headlineSmall),
                  const SizedBox(height: AppSpacing.xs),
                  VisitorStatusBadge(status: status),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xl),

        // ── Informações Básicas ─────────────────────────
        Text('Informações Básicas', style: AppTypography.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              DetailRow(
                icon: Icons.phone_outlined,
                label: 'Telefone',
                value: _textOrDash(visitor['phone']),
              ),
              const Divider(height: 1),
              DetailRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: _textOrDash(visitor['email']),
              ),
              const Divider(height: 1),
              DetailRow(
                icon: Icons.location_on_outlined,
                label: 'Endereço',
                value: _textOrDash(visitor['address']),
              ),
              const Divider(height: 1),
              DetailRow(
                icon: Icons.access_time_outlined,
                label: 'Cadastrado',
                value: relativeTime(),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ── Informações Pessoais ────────────────────────
        Text('Informações Pessoais', style: AppTypography.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              DetailRow(
                icon: Icons.cake_outlined,
                label: 'Data de Nascimento',
                value: _formatDate(visitor['birthDate'] as String?),
              ),
              if (age != null) ...[
                const Divider(height: 1),
                DetailRow(
                  icon: Icons.person_outline,
                  label: 'Idade',
                  value: '$age anos',
                ),
              ],
              const Divider(height: 1),
              DetailRow(
                icon: Icons.favorite_outline,
                label: 'Estado Civil',
                value: _textOrDash(visitor['maritalStatus']),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ── Informações Espirituais ─────────────────────
        Text('Informações Espirituais', style: AppTypography.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              DetailRow(
                icon: Icons.check_outlined,
                label: 'Batizado',
                value: (visitor['isBaptized'] as bool?) == true ? 'Sim' : 'Não',
              ),
              const Divider(height: 1),
              DetailRow(
                icon: Icons.group_outlined,
                label: 'Frequenta Célula',
                value: visitor['cellId'] != null ? 'Sim' : 'Não',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),

        // ── Informações Adicionais ──────────────────────
        if (_textOrDash(visitor['knownPersonName']).isNotEmpty ||
            _textOrDash(visitor['originChurch']).isNotEmpty ||
            (visitor['interests'] as List?)?.isNotEmpty == true) ...[
          Text('Informações Adicionais', style: AppTypography.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                if (_textOrDash(visitor['originChurch']).isNotEmpty) ...[
                  DetailRow(
                    icon: Icons.church_outlined,
                    label: 'Igreja de Origem',
                    value: _textOrDash(visitor['originChurch']),
                  ),
                  const Divider(height: 1),
                ],
                if (_textOrDash(visitor['knownPersonName']).isNotEmpty) ...[
                  DetailRow(
                    icon: Icons.person_add_outlined,
                    label: 'Conhecido Por',
                    value: _textOrDash(visitor['knownPersonName']),
                  ),
                  const Divider(height: 1),
                ],
                if ((visitor['interests'] as List?)?.isNotEmpty == true)
                  DetailRow(
                    icon: Icons.star_outline,
                    label: 'Interesses',
                    value: (visitor['interests'] as List).cast<String>().join(
                      ', ',
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],

        // ── Alterar Status ──────────────────────────────
        Text('Alterar status', style: AppTypography.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        const Wrap(
          spacing: AppSpacing.sm,
          children: [
            VisitorStatusChip(label: 'Novo'),
            VisitorStatusChip(label: 'Em acompanhamento'),
            VisitorStatusChip(label: 'Integrado'),
            VisitorStatusChip(label: 'Inativo'),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),

        // ── Ações ───────────────────────────────────────
        AppButton(
          label: visitor['cellId'] != null
              ? 'Direcionar para outra célula'
              : 'Direcionar para célula',
          variant: AppButtonVariant.secondary,
          prefixIcon: Icons.near_me_outlined,
          onPressed: () => _openAssignCell(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          height: AppSpacing.buttonHeightMd,
          child: FilledButton.icon(
            onPressed: () => _openWhatsApp(visitor['phone'] as String?),
            icon: const Icon(Icons.chat_outlined, size: 18),
            label: const Text('Enviar WhatsApp'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.whatsapp,
              foregroundColor: AppColors.white,
              textStyle: AppTypography.buttonLabel,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.base),
      ],
    );

    if (panel) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        child: content,
      );
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => SingleChildScrollView(
        controller: controller,
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        child: Column(
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
            const SizedBox(height: AppSpacing.xl),
            content,
          ],
        ),
      ),
    );
  }

  Future<void> _openAssignCell(BuildContext context) async {
    final assigned = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AssignVisitorCellSheet(visitor: visitor),
    );
    if (assigned == true) onChanged?.call();
  }

  static Future<void> _openWhatsApp(String? phone) async {
    final digits = (phone ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return;
    final normalized = digits.startsWith('55') ? digits : '55$digits';
    await launchUrl(
      Uri.parse('https://wa.me/$normalized'),
      mode: LaunchMode.externalApplication,
    );
  }
}

/// Localiza o endereço do visitante no mapa e lista as células da igreja mais
/// próximas, ordenadas da mais perto para a mais longe. Tocar numa célula já
/// direciona o visitante para ela.
///
/// Geocodifica com Nominatim (OpenStreetMap) — a mesma fonte usada no
/// auto-cadastro público — porque o app roda majoritariamente como PWA web, e
/// o plugin nativo `geocoding` não funciona nessa plataforma.
class _AssignVisitorCellSheet extends StatefulWidget {
  const _AssignVisitorCellSheet({required this.visitor});

  final Map<String, dynamic> visitor;

  @override
  State<_AssignVisitorCellSheet> createState() =>
      _AssignVisitorCellSheetState();
}

class _AssignVisitorCellSheetState extends State<_AssignVisitorCellSheet> {
  late final Dio _dio;
  bool _loading = true;
  String? _error;
  String? _savingId;
  List<Map<String, dynamic>> _cells = [];
  String? _resolvedAddress;

  /// true = `_cells` veio de `/cells/nearby` (ordenado, com `distanceKm`).
  /// false = fallback para `/cells` (todas, sem distância) — a distância é
  /// um extra; a lista em si é o que a tela promete sempre entregar.
  bool _hasDistance = false;

  /// Motivo de estar no modo sem distância — some quando a distância volta a
  /// funcionar. Não é `_error`: não impede o uso da tela.
  String? _notice;

  @override
  void initState() {
    super.initState();
    _dio = getIt<DioClient>().dio;
    _load();
  }

  String get _addressQuery {
    final parts = <String?>[
      widget.visitor['address'] as String?,
      widget.visitor['neighborhood'] as String?,
      widget.visitor['city'] as String?,
      widget.visitor['state'] as String?,
    ].where((p) => p != null && p.trim().isNotEmpty).toList();
    return parts.join(', ');
  }

  /// Geocodifica o endereço do visitante. Retorna as coordenadas em caso de
  /// sucesso; em qualquer falha, registra o motivo em [_notice] e retorna
  /// null — quem chama decide o que fazer sem distância.
  Future<(double, double)?> _tryGeocode() async {
    final query = _addressQuery;
    if (query.isEmpty) {
      _notice = 'Este visitante não tem endereço cadastrado.';
      return null;
    }
    try {
      final geoResp = await Dio().get(
        'https://nominatim.openstreetmap.org/search',
        queryParameters: {
          'format': 'json',
          'q': '$query, Brasil',
          'countrycodes': 'br',
          'limit': '1',
        },
        options: Options(headers: {'User-Agent': 'SistemaIgrejaApp/1.0'}),
      );
      final results = geoResp.data as List;
      if (results.isEmpty) {
        _notice = 'Não foi possível localizar "$query" no mapa.';
        return null;
      }
      final lat = double.tryParse(results[0]['lat'] as String? ?? '');
      final lng = double.tryParse(results[0]['lon'] as String? ?? '');
      if (lat == null || lng == null) {
        _notice = 'Não foi possível localizar "$query" no mapa.';
        return null;
      }
      _resolvedAddress = results[0]['display_name'] as String? ?? query;
      return (lat, lng);
    } catch (_) {
      _notice = 'Não foi possível conectar ao serviço de mapas.';
      return null;
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _notice = null;
    });

    final coords = await _tryGeocode();

    if (coords != null) {
      try {
        // Raio máximo permitido pelo endpoint — quero a lista inteira
        // ordenada, não só quem está bem perto.
        final resp = await _dio.get(
          '/cells/nearby',
          queryParameters: {'lat': coords.$1, 'lng': coords.$2, 'radius': 100},
        );
        final cells = ((resp.data as Map<String, dynamic>)['cells'] as List)
            .cast<Map<String, dynamic>>();
        if (!mounted) return;
        setState(() {
          _cells = cells;
          _hasDistance = true;
          _loading = false;
        });
        return;
      } on DioException {
        // Cai no fallback abaixo — a distância falhou, a lista não precisa.
        _notice = 'Não foi possível calcular a distância até as células.';
      }
    }

    // Fallback: geocodificação ou busca por distância falharam, mas a lista
    // de células em si é o mínimo que esta tela promete entregar.
    try {
      final resp = await _dio.get('/cells');
      final cells =
          ((resp.data as Map<String, dynamic>)['cells'] as List)
              .cast<Map<String, dynamic>>()
            ..sort(
              (a, b) => (a['name'] as String? ?? '').compareTo(
                b['name'] as String? ?? '',
              ),
            );
      if (!mounted) return;
      setState(() {
        _cells = cells;
        _hasDistance = false;
        _notice ??= 'Não foi possível calcular a distância até as células.';
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar células';
        _loading = false;
      });
    }
  }

  Future<void> _assign(String cellId) async {
    setState(() => _savingId = cellId);
    try {
      await _dio.patch(
        '/visitors/${widget.visitor['id']}/assign-cell',
        data: {'cellId': cellId},
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _savingId = null);
      showDashboardSnackBar(
        context,
        e.response?.data?['error']?['message'] as String? ??
            'Erro ao direcionar visitante',
      );
    }
  }

  static const _dayLabels = {
    'segunda': 'seg',
    'terca': 'ter',
    'quarta': 'qua',
    'quinta': 'qui',
    'sexta': 'sex',
    'sabado': 'sáb',
    'domingo': 'dom',
  };

  /// pt-BR: 3.7 → "3,7 km"; abaixo de 1 km mostra em metros.
  static String _formatDistance(num km) {
    if (km < 1) return '${(km * 1000).round()} m';
    return '${km.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        child: Column(
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
            Text('Direcionar para célula', style: AppTypography.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _hasDistance && _resolvedAddress != null
                  ? 'A partir de: $_resolvedAddress'
                  : (_notice ??
                        'Calculando distância a partir do endereço '
                            'cadastrado...'),
              style: AppTypography.bodySmall.copyWith(
                // Aviso de que a distância não pôde ser calculada usa a cor de
                // atenção; texto normal (carregando ou endereço resolvido)
                // fica na tinta neutra de sempre.
                color: (!_loading && !_hasDistance && _notice != null)
                    ? AppColors.warning
                    : mutedColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.base),
            if (_loading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.base,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.base),
                        AppButton(
                          label: 'Tentar novamente',
                          variant: AppButtonVariant.outline,
                          isFullWidth: false,
                          onPressed: _load,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (_cells.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'Nenhuma célula com localização cadastrada foi '
                    'encontrada.',
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyMedium.copyWith(color: mutedColor),
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  itemCount: _cells.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, i) {
                    final cell = _cells[i];
                    final id = cell['id'] as String;
                    final isCurrent = id == widget.visitor['cellId'];
                    final day = _dayLabels[cell['dayOfWeek'] as String?] ?? '';
                    final time = cell['time'] as String? ?? '';
                    final leaderName = cell['leaderName'] as String?;
                    final distanceKm = cell['distanceKm'] as num? ?? 0;

                    return AppCard(
                      onTap: _savingId != null ? null : () => _assign(id),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  cell['name'] as String? ?? 'Célula',
                                  style: AppTypography.titleSmall,
                                ),
                                const SizedBox(height: AppSpacing.xs2),
                                Text(
                                  [
                                    ?leaderName,
                                    if (day.isNotEmpty && time.isNotEmpty)
                                      '$day $time',
                                  ].join(' · '),
                                  style: AppTypography.bodySmall.copyWith(
                                    color: mutedColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (isCurrent) ...[
                                  const SizedBox(height: AppSpacing.xs),
                                  const AppBadge(
                                    label: 'Célula atual',
                                    variant: AppBadgeVariant.info,
                                    size: AppBadgeSize.sm,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          if (_savingId == id)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (_hasDistance)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Icon(
                                  Icons.near_me_outlined,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(height: AppSpacing.xs2),
                                Text(
                                  _formatDistance(distanceKm),
                                  style: AppTypography.labelLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            )
                          else
                            Icon(
                              Icons.chevron_right,
                              size: 20,
                              color: mutedColor,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
