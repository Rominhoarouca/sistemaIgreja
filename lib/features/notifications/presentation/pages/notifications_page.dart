import 'package:flutter/material.dart';
import '../../../../design_system/design_system.dart';

/// Notifications page — lists app notifications for the logged-in user.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static final _notifications = [
    _NotificationItem(
      icon: Icons.person_add_outlined,
      color: AppColors.primary,
      title: 'Novo visitante encaminhado',
      body: 'Maria Fernandes foi encaminhada para sua célula.',
      time: 'há 5 min',
      isRead: false,
    ),
    _NotificationItem(
      icon: Icons.check_circle_outline,
      color: AppColors.success,
      title: 'Visitante integrado',
      body: 'Paulo Santos foi marcado como integrado.',
      time: 'há 2 horas',
      isRead: false,
    ),
    _NotificationItem(
      icon: Icons.event_available_outlined,
      color: AppColors.accent,
      title: 'Reunião de célula hoje',
      body: 'Lembrete: encontro da Célula Esperança às 19h.',
      time: 'há 3 horas',
      isRead: true,
    ),
    _NotificationItem(
      icon: Icons.file_download_outlined,
      color: AppColors.secondary,
      title: 'Novo material disponível',
      body: 'Lição 4: Servindo com Propósito foi adicionada.',
      time: 'ontem',
      isRead: true,
    ),
    _NotificationItem(
      icon: Icons.trending_up_outlined,
      color: AppColors.info,
      title: 'Relatório semanal',
      body: 'O relatório da semana está disponível para visualização.',
      time: '2 dias atrás',
      isRead: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Notificações'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () => setState(() {
                for (final n in _notifications) {
                  n.isRead = true;
                }
              }),
              child: Text(
                'Marcar todas como lidas',
                style: AppTypography.labelMedium,
              ),
            ),
        ],
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _notifications.isEmpty
          ? _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              itemCount: _notifications.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final n = _notifications[i];
                return _NotificationTile(
                  item: n,
                  onTap: () => setState(() => n.isRead = true),
                );
              },
            ),
    );
  }
}

class _NotificationItem {
  final IconData icon;
  final Color color;
  final String title;
  final String body;
  final String time;
  bool isRead;

  _NotificationItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
    required this.time,
    required this.isRead,
  });
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final _NotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: item.isRead
            ? null
            : AppColors.primarySurface.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.pagePaddingH,
          vertical: AppSpacing.md,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: item.color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(item.icon, color: item.color, size: 22),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: AppTypography.titleSmall.copyWith(
                            fontWeight: item.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs2),
                  Text(
                    item.body,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.time,
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.grey400,
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

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: AppColors.grey300,
          ),
          const SizedBox(height: AppSpacing.base),
          Text(
            'Nenhuma notificação',
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
