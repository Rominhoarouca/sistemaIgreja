import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart' show AuthorizationStatus;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/firebase/firebase_service.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/app_snackbar.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../../routing/role_home.dart';
import 'admin_create_notification_page.dart';
import 'admin_notifications_list_page.dart';
import 'notification_detail_page.dart';
import '../../../../injection/injection.dart';

/// Notifications page — lists the current user's notifications (title only).
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late final Dio _dio;
  bool _isLoading = true;
  String? _error;
  List<_NotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _dio = getIt<DioClient>().dio;
    _load();
    _ensurePushPermission();
  }

  /// Pede permissão de notificação aqui, e não no boot: esta é a tela onde o
  /// usuário demonstra interesse em receber avisos, então o pedido tem
  /// contexto. Pedir na primeira abertura do app costuma render recusa.
  Future<void> _ensurePushPermission() async {
    final status = await FirebaseService.instance.pushStatus();
    debugPrint('FCM status atual: $status');
    // Só pula quando já está concedida. Não dá para testar `notDetermined`:
    // no Android o `getNotificationSettings` nunca devolve esse valor — sem
    // permissão ele responde `denied`, e o guard antigo pulava sempre.
    if (status == AuthorizationStatus.authorized ||
        status == AuthorizationStatus.provisional) {
      return;
    }
    final token = await FirebaseService.instance.requestPushPermission();
    debugPrint('FCM token do aparelho: ${token ?? "(não concedido)"}');
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final resp = await _dio.get('/notifications');
      final list = (resp.data['notifications'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(_NotificationItem.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _notifications = list;
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = extractDioErrorMessage(e, fallback: 'Erro ao carregar notificações');
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    final unread = _notifications.where((n) => !n.isRead).toList();
    if (unread.isEmpty) return;
    setState(() {
      for (final n in unread) {
        n.isRead = true;
      }
    });
    try {
      await _dio.patch('/notifications/read-all');
    } on DioException catch (e) {
      AppSnackbar.error(
        extractDioErrorMessage(e, fallback: 'Erro ao marcar notificações como lidas'),
      );
    }
  }

  Future<void> _openNotification(_NotificationItem item) async {
    setState(() => item.isRead = true);
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => NotificationDetailPage(id: item.id)),
    );
  }

  Future<void> _openCreateNotification() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AdminCreateNotificationPage()),
    );
    if (created == true) _load();
  }

  Future<void> _openManageNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AdminNotificationsListPage()),
    );
  }

  /// Volta para a tela anterior; sem pilha, cai na home do perfil do usuário.
  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final state = context.read<AuthBloc>().state;
    final home = state is AuthAuthenticated
        ? homeRouteForRole(orderedRoles(state.user).first)
        : '/';
    context.go(home);
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;
    final isAdmin = context.select<AuthBloc, bool>((bloc) {
      final state = bloc.state;
      return state is AuthAuthenticated && state.user.isAdmin;
    });

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        // Botão de voltar explícito: a rota vive dentro do shell do admin e,
        // dependendo de como se chega nela, o `automaticallyImplyLeading` não
        // encontra nada para desempilhar — o líder ficava preso na tela.
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Voltar',
          onPressed: _goBack,
        ),
        title: const Text('Notificações'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.manage_accounts_outlined),
              tooltip: 'Notificações enviadas',
              onPressed: _openManageNotifications,
            ),
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllRead,
              child: Text('Marcar todas como lidas', style: AppTypography.labelMedium),
            ),
        ],
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.error),
                    textAlign: TextAlign.center,
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
            )
          : _notifications.isEmpty
          ? const _EmptyState()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: _notifications.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                itemBuilder: (context, i) {
                  final n = _notifications[i];
                  return _NotificationTile(item: n, onTap: () => _openNotification(n));
                },
              ),
            ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              onPressed: _openCreateNotification,
              icon: const Icon(Icons.add_alert_outlined),
              label: const Text('Nova notificação'),
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.white,
            )
          : null,
    );
  }
}

class _NotificationItem {
  final String id;
  final String title;
  bool isRead;
  final DateTime createdAt;

  _NotificationItem({
    required this.id,
    required this.title,
    required this.isRead,
    required this.createdAt,
  });

  factory _NotificationItem.fromJson(Map<String, dynamic> json) => _NotificationItem(
    id: json['id'] as String,
    title: json['title'] as String,
    isRead: json['isRead'] as bool? ?? false,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
  );
}

String _relativeTime(DateTime dateTime) {
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return 'agora mesmo';
  if (diff.inMinutes < 60) return 'há ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'há ${diff.inHours}h';
  if (diff.inDays < 7) return 'há ${diff.inDays} dias';
  return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
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
        color: item.isRead ? null : AppColors.primarySurface.withValues(alpha: 0.4),
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
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.campaign_outlined, color: AppColors.primary, size: 22),
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
                            fontWeight: item.isRead ? FontWeight.w500 : FontWeight.w700,
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
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    _relativeTime(item.createdAt),
                    style: AppTypography.labelSmall.copyWith(color: AppColors.grey400),
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
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.notifications_off_outlined, size: 64, color: AppColors.grey300),
          const SizedBox(height: AppSpacing.base),
          Text(
            'Nenhuma notificação',
            style: AppTypography.titleMedium.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
