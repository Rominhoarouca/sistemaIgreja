import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/app_snackbar.dart';
import 'notification_detail_page.dart';
import '../../../../injection/injection.dart';

/// Admin-only screen listing every notification created for the church
/// (not just the ones addressed to the current admin), with preview and
/// edit access to each one.
class AdminNotificationsListPage extends StatefulWidget {
  const AdminNotificationsListPage({super.key});

  @override
  State<AdminNotificationsListPage> createState() => _AdminNotificationsListPageState();
}

class _AdminNotificationsListPageState extends State<AdminNotificationsListPage> {
  late final Dio _dio;
  bool _isLoading = true;
  String? _error;
  List<_AdminNotificationItem> _notifications = [];

  @override
  void initState() {
    super.initState();
    _dio = getIt<DioClient>().dio;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final resp = await _dio.get('/notifications/admin');
      final list = (resp.data['notifications'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map(_AdminNotificationItem.fromJson)
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

  Future<void> _openNotification(_AdminNotificationItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NotificationDetailPage(id: item.id, adminMode: true),
      ),
    );
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Notificações enviadas')),
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
          ? Center(
              child: Text(
                'Nenhuma notificação enviada ainda',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                itemCount: _notifications.length,
                separatorBuilder: (_, _) => const Divider(height: 1, indent: 72),
                itemBuilder: (context, i) {
                  final n = _notifications[i];
                  return _AdminNotificationTile(item: n, onTap: () => _openNotification(n));
                },
              ),
            ),
    );
  }
}

class _AdminNotificationItem {
  final String id;
  final String title;
  final DateTime createdAt;
  final int recipientCount;

  _AdminNotificationItem({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.recipientCount,
  });

  factory _AdminNotificationItem.fromJson(Map<String, dynamic> json) => _AdminNotificationItem(
    id: json['id'] as String,
    title: json['title'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    recipientCount: json['recipientCount'] as int? ?? 0,
  );
}

class _AdminNotificationTile extends StatelessWidget {
  const _AdminNotificationTile({required this.item, required this.onTap});

  final _AdminNotificationItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = item.createdAt;
    final dateStr =
        '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

    return InkWell(
      onTap: onTap,
      child: Container(
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
                  Text(item.title, style: AppTypography.titleSmall),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    '$dateStr · ${item.recipientCount} destinatário(s)',
                    style: AppTypography.labelSmall.copyWith(color: AppColors.grey400),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.grey400),
          ],
        ),
      ),
    );
  }
}
