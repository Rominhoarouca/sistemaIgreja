import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../design_system/design_system.dart';
import '../../../../injection/injection.dart';
import '../../data/kids_models.dart';
import '../../data/kids_repository.dart';
import '../widgets/kids_widgets.dart';

/// Tela inicial do ministério infantil: as salas do professor, com a sessão
/// aberta em destaque. É a tela mais usada do módulo — abre direto no que
/// importa no domingo de manhã.
class KidsHomePage extends StatefulWidget {
  const KidsHomePage({super.key});

  @override
  State<KidsHomePage> createState() => _KidsHomePageState();
}

class _KidsHomePageState extends State<KidsHomePage> {
  late final KidsRepository _repo;
  bool _loading = true;
  String? _error;
  List<KidsRoom> _rooms = [];
  List<KidsAlert> _openAlerts = [];

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
      final rooms = await _repo.listRooms();
      // Alertas abertos aparecem no topo: são a única coisa que interrompe o
      // fluxo normal da sala.
      final alerts = await _repo.listAlerts(status: 'OPEN');
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
        _openAlerts = alerts;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = kidsErrorMessage(e, 'Erro ao carregar as salas');
        _loading = false;
      });
    }
  }

  Future<void> _openSession(KidsRoom room) async {
    final existing = room.openSession;
    if (existing != null) {
      await context.push('/kids/sessions/${existing.id}');
      if (mounted) _load();
      return;
    }

    final data = await showDialog<({String serviceName, String? lesson})>(
      context: context,
      builder: (_) => const _OpenSessionDialog(),
    );
    if (data == null) return;

    try {
      final session = await _repo.openSession(
        room.id,
        serviceName: data.serviceName,
        lesson: data.lesson,
      );
      if (!mounted) return;
      await context.push('/kids/sessions/${session.id}');
      if (mounted) _load();
    } on DioException catch (e) {
      if (!mounted) return;
      showKidsError(
        context,
        kidsErrorMessage(e, 'Não foi possível abrir a sala'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kids'),
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
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: AppLoadingIndicator(size: 32));
    if (_error != null) {
      return AppErrorState(message: _error!, onRetry: _load);
    }
    if (_rooms.isEmpty) {
      return const Center(
        child: AppEmptyState(
          title: 'Nenhuma sala para você',
          subtitle:
              'Peça ao administrador para criar a sala e vincular você como professor.',
          icon: Icons.meeting_room_outlined,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        children: [
          if (_openAlerts.isNotEmpty) ...[
            AppSectionHeader(title: 'Alertas abertos (${_openAlerts.length})'),
            const SizedBox(height: AppSpacing.sm),
            for (final alert in _openAlerts.take(3))
              _AlertSummaryCard(alert: alert, onTap: _load),
            const SizedBox(height: AppSpacing.base),
          ],
          AppSectionHeader(title: 'Minhas salas'),
          const SizedBox(height: AppSpacing.sm),
          for (final room in _rooms)
            _RoomCard(room: room, onTap: () => _openSession(room)),
          const SizedBox(height: AppSpacing.xl2),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  const _RoomCard({required this.room, required this.onTap});

  final KidsRoom room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;
    final session = room.openSession;

    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: Icon(
                  Icons.meeting_room_outlined,
                  color: isDark ? AppColors.linkDark : AppColors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(room.name, style: AppTypography.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (room.ageRangeLabel.isNotEmpty) room.ageRangeLabel,
                        '${room.capacity} lugares',
                      ].join(' · '),
                      style: AppTypography.bodySmall.copyWith(
                        color: mutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              AppBadge(
                label: session == null ? 'Fechada' : 'Aberta',
                variant: session == null
                    ? AppBadgeVariant.neutral
                    : AppBadgeVariant.success,
                size: AppBadgeSize.sm,
              ),
            ],
          ),
          if (session != null) ...[
            const SizedBox(height: AppSpacing.md),
            KidsOccupancyBar(
              current: session.presentCount,
              capacity: session.capacity,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.event_outlined, size: 14, color: mutedColor),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '${session.serviceName} · aberta às ${formatTime(session.openedAt)}',
                    style: AppTypography.bodySmall.copyWith(color: mutedColor),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (session.openAlerts > 0)
                  AppBadge(
                    label: '${session.openAlerts} alerta(s)',
                    variant: AppBadgeVariant.error,
                    size: AppBadgeSize.sm,
                  ),
              ],
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Abrir sala',
              prefixIcon: Icons.play_arrow_rounded,
              size: AppButtonSize.sm,
              variant: AppButtonVariant.outline,
              onPressed: onTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _AlertSummaryCard extends StatelessWidget {
  const _AlertSummaryCard({required this.alert, required this.onTap});

  final KidsAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = alertLevelColor(alert.level, isDark: isDark);

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Container(width: 4, height: 40, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${alert.childName} · ${alert.roomName}',
                  style: AppTypography.titleSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  alert.message,
                  style: AppTypography.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          AppBadge(
            label: alert.level.label,
            variant: alertLevelBadge(alert.level),
            size: AppBadgeSize.sm,
          ),
        ],
      ),
    );
  }
}

class _OpenSessionDialog extends StatefulWidget {
  const _OpenSessionDialog();

  @override
  State<_OpenSessionDialog> createState() => _OpenSessionDialogState();
}

class _OpenSessionDialogState extends State<_OpenSessionDialog> {
  final _serviceCtrl = TextEditingController(text: 'Culto');
  final _lessonCtrl = TextEditingController();

  @override
  void dispose() {
    _serviceCtrl.dispose();
    _lessonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Abrir sala'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            label: 'Culto',
            hint: 'Culto da manhã',
            controller: _serviceCtrl,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(
            label: 'Lição (opcional)',
            hint: 'Tema da aula de hoje',
            controller: _lessonCtrl,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final name = _serviceCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.of(context).pop((
              serviceName: name,
              lesson: _lessonCtrl.text.trim().isEmpty
                  ? null
                  : _lessonCtrl.text.trim(),
            ));
          },
          child: const Text('Abrir'),
        ),
      ],
    );
  }
}
