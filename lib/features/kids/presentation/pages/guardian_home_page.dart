import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/firebase/firebase_service.dart';
import '../../../../design_system/design_system.dart';
import '../../../../injection/injection.dart';
import '../../../../shared/utils/plural.dart';
import '../../data/kids_models.dart';
import '../../data/kids_repository.dart';
import '../widgets/kids_widgets.dart';
import 'guardian_child_detail_page.dart';
import 'guardian_child_form_page.dart';

/// Home do responsável: onde cada filho está agora, o QR de entrega/retirada e
/// os alertas recebidos. É a única área do app que esse papel enxerga.
class GuardianHomePage extends StatefulWidget {
  const GuardianHomePage({super.key});

  @override
  State<GuardianHomePage> createState() => _GuardianHomePageState();
}

class _GuardianHomePageState extends State<GuardianHomePage> {
  late final KidsRepository _repo;
  bool _loading = true;
  String? _error;
  List<KidsChild> _children = [];
  List<KidsAlert> _alerts = [];

  @override
  void initState() {
    super.initState();
    _repo = KidsRepository(getIt<Dio>());
    _load();
    _ensurePushPermission();
  }

  /// O responsável é o principal destinatário de push do sistema — o alerta da
  /// salinha existe para chegar nele. Como este papel não tem a tela de
  /// Notificações, o pedido de permissão precisa acontecer aqui; esta tela já
  /// é sobre receber avisos, então o contexto é o certo.
  /// Sempre chama, mesmo já autorizado: com a permissão concedida o iOS não
  /// abre diálogo, e é esta chamada que registra o aparelho no APNs. Sair antes
  /// por "já autorizado" era o que deixava o iPad sem token.
  Future<void> _ensurePushPermission() async {
    await FirebaseService.instance.requestPushPermission();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final children = await _repo.myChildren();
      final alerts = await _repo.myAlerts();
      if (!mounted) return;
      setState(() {
        _children = children;
        _alerts = alerts;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = kidsErrorMessage(e, 'Erro ao carregar seus filhos');
        _loading = false;
      });
    }
  }

  /// Só o que ainda pede ação: sala aberta e aviso não resolvido. Aviso de
  /// sala fechada não sai da vida do responsável — vai para o histórico.
  List<KidsAlert> get _liveAlerts =>
      _alerts.where((a) => a.isLive).toList();

  /// Um grupo por sala, na ordem do aviso mais recente. Com vários filhos em
  /// salas diferentes isso separa o que é de cada uma.
  List<MapEntry<String, List<KidsAlert>>> get _alertsByRoom {
    final grupos = <String, List<KidsAlert>>{};
    for (final alert in _liveAlerts) {
      grupos.putIfAbsent(alert.roomName, () => []).add(alert);
    }
    return grupos.entries.toList()
      ..sort((a, b) => b.value.first.createdAt.compareTo(a.value.first.createdAt));
  }

  /// Quantos ainda esperam o "Estou indo". É o que decide se vale abrir o
  /// grupo, então precisa estar legível com ele fechado.
  static String? _pendentes(List<KidsAlert> alerts) {
    final n = alerts.where((a) => a.status == KidsAlertStatus.open).length;
    if (n == 0) return null;
    return n == 1 ? '1 aguarda confirmação' : '$n aguardam confirmação';
  }

  Future<void> _addChild() async {
    final created = await Navigator.of(context).push<KidsChild>(
      MaterialPageRoute(builder: (_) => const GuardianChildFormPage()),
    );
    if (created != null) _load();
  }

  Future<void> _openChild(KidsChild child) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GuardianChildDetailPage(childId: child.id),
      ),
    );
    _load();
  }

  Future<void> _acknowledge(KidsAlert alert) async {
    try {
      await _repo.acknowledgeAlert(alert.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A sala foi avisada de que você está a caminho'),
        ),
      );
      _load();
    } on DioException catch (e) {
      if (!mounted) return;
      showKidsError(context, kidsErrorMessage(e, 'Não foi possível confirmar'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meus filhos'),
        actions: [
          IconButton(
            tooltip: 'Histórico de avisos',
            icon: const Icon(Icons.history),
            onPressed: () => context.push(AppRoutes.guardianAlerts),
          ),
          IconButton(
            tooltip: 'Adicionar filho',
            icon: const Icon(Icons.person_add_alt_outlined),
            onPressed: _addChild,
          ),
          IconButton(
            tooltip: isDark ? 'Modo claro' : 'Modo escuro',
            icon: Icon(
              isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: () => ThemeController.instance.toggle(context),
          ),
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => context.push('/profile'),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.guardianQrCode),
        icon: const Icon(Icons.qr_code_2),
        label: const Text('Meu QR Code'),
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: AppLoadingIndicator(size: 32));
    if (_error != null) return AppErrorState(message: _error!, onRetry: _load);
    if (_children.isEmpty) {
      return Center(
        child: AppEmptyState(
          title: 'Nenhuma criança vinculada',
          subtitle:
              'Cadastre seu filho ou fale com a equipe do ministério infantil para vinculá-lo à sua conta.',
          icon: Icons.child_care_outlined,
          action: _addChild,
          actionLabel: 'Adicionar filho',
        ),
      );
    }

    // Em tablet/desktop a coluna para de crescer: sem isso os cards viravam
    // faixas de ponta a ponta da tela.
    return AppContentWidth(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
          children: [
            if (_alertsByRoom.isNotEmpty) ...[
              AppSectionHeader(title: 'Avisos da sala'),
              const SizedBox(height: AppSpacing.sm),
              for (final grupo in _alertsByRoom)
                _AlertGroup(
                  title: grupo.key,
                  subtitle: _pendentes(grupo.value),
                  alerts: grupo.value,
                  onAcknowledge: _acknowledge,
                ),
              const SizedBox(height: AppSpacing.base),
            ],
            AppSectionHeader(title: 'Filhos'),
            const SizedBox(height: AppSpacing.sm),
            for (final child in _children)
              _ChildStatusCard(child: child, onTap: () => _openChild(child)),
            const SizedBox(height: AppSpacing.xl2),
          ],
        ),
      ),
    );
  }
}

class _ChildStatusCard extends StatelessWidget {
  const _ChildStatusCard({required this.child, this.onTap});

  final KidsChild child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;
    final checkin = child.openCheckin;

    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          AppAvatar(initials: child.initials),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(child.name, style: AppTypography.titleSmall),
                const SizedBox(height: 2),
                Text(
                  checkin == null
                      ? 'Fora da salinha'
                      : 'Na sala desde ${formatTime(checkin.checkinAt)} · crachá ${checkin.badgeCode}',
                  style: AppTypography.bodySmall.copyWith(color: mutedColor),
                ),
              ],
            ),
          ),
          AppBadge(
            label: checkin == null ? 'Em casa' : 'Na sala',
            variant: checkin == null
                ? AppBadgeVariant.neutral
                : AppBadgeVariant.success,
            size: AppBadgeSize.sm,
          ),
        ],
      ),
    );
  }
}

/// Avisos de uma sala (ou de um dia, no histórico) recolhidos num bloco só.
///
/// Um domingo movimentado rende muitos avisos, e enfileirar cada um como cartão
/// empurrava a lista de filhos para fora da tela. Fechado por padrão, mostrando
/// no cabeçalho o que dá para decidir sem abrir: quantos são e o nível do mais
/// grave.
///
/// Poucos avisos já vêm abertos: recolher três cartões não economiza tela e só
/// custa um toque. O colapso vale a partir do ponto em que a lista começa a
/// empurrar o resto da página para baixo.
///
/// O que fica escondido continua anunciado no cabeçalho — cor e rótulo do nível
/// mais grave, quantos são e quantos aguardam confirmação. E a emergência de
/// verdade chega por push, não por esta tela.
class _AlertGroup extends StatelessWidget {
  const _AlertGroup({
    required this.title,
    required this.alerts,
    this.subtitle,
    this.onAcknowledge,
    this.showRoomInCards = false,
  });

  final String title;
  final String? subtitle;
  final List<KidsAlert> alerts;
  final void Function(KidsAlert alert)? onAcknowledge;

  /// Ligue quando o título do grupo não for a sala — caso do histórico, que
  /// agrupa por dia.
  final bool showRoomInCards;

  /// Os níveis são declarados em ordem crescente de urgência, então o maior
  /// `index` é o mais grave.
  KidsAlertLevel get _highestLevel =>
      alerts.map((a) => a.level).reduce((a, b) => a.index >= b.index ? a : b);

  /// Acima disto a lista deixa de caber junto com o resto da home.
  static const _limiteParaRecolher = 3;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;
    final count = alerts.length;

    return AppCard(
      padding: EdgeInsets.zero,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Theme(
        // O ExpansionTile desenha uma linha acima e abaixo quando aberto, que
        // dentro do card vira uma borda dupla.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: count <= _limiteParaRecolher,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          title: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: alertLevelColor(_highestLevel, isDark: isDark),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppBadge(
                label: plural(count, 'aviso'),
                variant: alertLevelBadge(_highestLevel),
                size: AppBadgeSize.sm,
              ),
            ],
          ),
          subtitle: subtitle == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(top: 2, left: 18),
                  child: Text(
                    subtitle!,
                    style: AppTypography.bodySmall.copyWith(color: mutedColor),
                  ),
                ),
          children: [
            for (final alert in alerts)
              _GuardianAlertCard(
                alert: alert,
                showRoom: showRoomInCards,
                onAcknowledge:
                    onAcknowledge != null &&
                        alert.status == KidsAlertStatus.open
                    ? () => onAcknowledge!(alert)
                    : null,
              ),
          ],
        ),
      ),
    );
  }
}

class _GuardianAlertCard extends StatelessWidget {
  const _GuardianAlertCard({
    required this.alert,
    this.onAcknowledge,
    this.showRoom = true,
  });

  final KidsAlert alert;
  final VoidCallback? onAcknowledge;

  /// Na home o grupo já é a sala, e repeti-la em cada cartão só rouba a largura
  /// do nome da criança. No histórico o grupo é o dia, então a sala precisa
  /// aparecer aqui.
  final bool showRoom;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;
    final color = alertLevelColor(alert.level, isDark: isDark);

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  showRoom
                      ? '${alert.childName} · ${alert.roomName}'
                      : alert.childName,
                  style: AppTypography.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              AppBadge(
                label: alert.level.label,
                variant: alertLevelBadge(alert.level),
                size: AppBadgeSize.sm,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(alert.message, style: AppTypography.bodyMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${formatDate(alert.createdAt)} às ${formatTime(alert.createdAt)} · ${alert.createdByName}',
            style: AppTypography.bodySmall.copyWith(color: mutedColor),
          ),
          if (onAcknowledge != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Estou indo',
              size: AppButtonSize.sm,
              onPressed: onAcknowledge,
            ),
          ] else if (alert.acknowledgedAt != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.check_circle_outline, size: 14, color: mutedColor),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Você confirmou às ${formatTime(alert.acknowledgedAt!)}',
                  style: AppTypography.bodySmall.copyWith(color: mutedColor),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// QR Code do responsável, renovado automaticamente.
///
/// O token vale 60 segundos e some depois de usado — é isso que impede que um
/// print do código vire chave permanente da criança. A tela renova sozinha um
/// pouco antes de expirar.
class GuardianQrPage extends StatefulWidget {
  const GuardianQrPage({super.key});

  @override
  State<GuardianQrPage> createState() => _GuardianQrPageState();
}

class _GuardianQrPageState extends State<GuardianQrPage> {
  late final KidsRepository _repo;
  Timer? _timer;
  String? _token;
  String? _error;
  int _secondsLeft = 0;

  @override
  void initState() {
    super.initState();
    _repo = KidsRepository(getIt<Dio>());
    _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final result = await _repo.myQr();
      if (!mounted) return;
      setState(() {
        _token = result.token;
        _error = null;
        // Renova 15 s antes do vencimento: o QR nunca aparece "morto" na tela.
        _secondsLeft = result.expiresIn - 15;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) return;
        setState(() => _secondsLeft -= 1);
        if (_secondsLeft <= 0) {
          timer.cancel();
          _refresh();
        }
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = kidsErrorMessage(e, 'Não foi possível gerar o QR'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;

    return Scaffold(
      appBar: AppBar(title: const Text('Meu QR Code')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
          child: _error != null
              ? AppErrorState(message: _error!, onRetry: _refresh)
              : _token == null
              ? const AppLoadingIndicator(size: 32)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.base),
                      decoration: BoxDecoration(
                        // Fundo branco sempre: leitor de QR não lê código
                        // invertido em tema escuro.
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLg,
                        ),
                      ),
                      child: QrImageView(
                        data: _token!,
                        size: 260,
                        backgroundColor: AppColors.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.base),
                    Text(
                      'Mostre este código na entrega e na retirada',
                      style: AppTypography.titleSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      _secondsLeft > 0
                          ? 'Renova em ${_secondsLeft}s'
                          : 'Renovando…',
                      style: AppTypography.bodySmall.copyWith(
                        color: mutedColor,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.base),
                    AppButton(
                      label: 'Gerar novo agora',
                      variant: AppButtonVariant.outline,
                      size: AppButtonSize.sm,
                      isFullWidth: false,
                      onPressed: _refresh,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Histórico de avisos recebidos pelo responsável.
class GuardianAlertsPage extends StatefulWidget {
  const GuardianAlertsPage({super.key});

  @override
  State<GuardianAlertsPage> createState() => _GuardianAlertsPageState();
}

class _GuardianAlertsPageState extends State<GuardianAlertsPage> {
  late final KidsRepository _repo;
  bool _loading = true;
  String? _error;
  List<KidsAlert> _alerts = [];

  @override
  void initState() {
    super.initState();
    _repo = KidsRepository(getIt<Dio>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final alerts = await _repo.myAlerts(limit: 200);
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = kidsErrorMessage(e, 'Erro ao carregar os avisos');
        _loading = false;
      });
    }
  }

  /// Um grupo por dia de culto, do mais recente para o mais antigo. O
  /// responsável procura por "o domingo passado", não por um aviso solto.
  List<MapEntry<DateTime, List<KidsAlert>>> get _byDay {
    final grupos = <DateTime, List<KidsAlert>>{};
    for (final alert in _alerts) {
      final d = alert.day;
      grupos.putIfAbsent(DateTime(d.year, d.month, d.day), () => []).add(alert);
    }
    return grupos.entries.toList()..sort((a, b) => b.key.compareTo(a.key));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Histórico de avisos')),
      body: _loading
          ? const Center(child: AppLoadingIndicator(size: 32))
          : _error != null
          ? AppErrorState(message: _error!, onRetry: _load)
          : _alerts.isEmpty
          ? const Center(
              child: AppEmptyState(
                title: 'Nenhum aviso',
                subtitle:
                    'Você será avisado aqui se a sala precisar falar com você.',
                icon: Icons.notifications_none,
              ),
            )
          : AppContentWidth(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
                  children: [
                    for (final dia in _byDay)
                      _AlertGroup(
                        title: formatDate(dia.key),
                        subtitle: _salas(dia.value),
                        alerts: dia.value,
                        showRoomInCards: true,
                      ),
                    const SizedBox(height: AppSpacing.xl2),
                  ],
                ),
              ),
            ),
    );
  }

  /// Salas daquele dia, sem repetir — no histórico o dia é o título, então a
  /// sala precisa aparecer em algum lugar para o grupo fechado fazer sentido.
  static String _salas(List<KidsAlert> alerts) =>
      alerts.map((a) => a.roomName).toSet().join(' · ');
}
