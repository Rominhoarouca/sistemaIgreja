import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../design_system/design_system.dart';
import '../../../../injection/injection.dart';
import '../../data/kids_models.dart';
import '../../data/kids_repository.dart';
import '../widgets/kids_widgets.dart';

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

  List<KidsAlert> get _openAlerts =>
      _alerts.where((a) => a.status != KidsAlertStatus.resolved).toList();

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
      return const Center(
        child: AppEmptyState(
          title: 'Nenhuma criança vinculada',
          subtitle:
              'Fale com a equipe do ministério infantil para vincular seus filhos à sua conta.',
          icon: Icons.child_care_outlined,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        children: [
          if (_openAlerts.isNotEmpty) ...[
            AppSectionHeader(title: 'Avisos da sala'),
            const SizedBox(height: AppSpacing.sm),
            for (final alert in _openAlerts)
              _GuardianAlertCard(
                alert: alert,
                onAcknowledge: alert.status == KidsAlertStatus.open
                    ? () => _acknowledge(alert)
                    : null,
              ),
            const SizedBox(height: AppSpacing.base),
          ],
          AppSectionHeader(title: 'Filhos'),
          const SizedBox(height: AppSpacing.sm),
          for (final child in _children) _ChildStatusCard(child: child),
          const SizedBox(height: AppSpacing.xl2),
        ],
      ),
    );
  }
}

class _ChildStatusCard extends StatelessWidget {
  const _ChildStatusCard({required this.child});

  final KidsChild child;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;
    final checkin = child.openCheckin;

    return AppCard(
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

class _GuardianAlertCard extends StatelessWidget {
  const _GuardianAlertCard({required this.alert, this.onAcknowledge});

  final KidsAlert alert;
  final VoidCallback? onAcknowledge;

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
                  '${alert.childName} · ${alert.roomName}',
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
      final alerts = await _repo.myAlerts();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Avisos')),
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
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
                children: [
                  for (final alert in _alerts) _GuardianAlertCard(alert: alert),
                  const SizedBox(height: AppSpacing.xl2),
                ],
              ),
            ),
    );
  }
}
