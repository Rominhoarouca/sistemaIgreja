import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/app_snackbar.dart';
import 'admin_edit_notification_page.dart';
import '../../../../injection/injection.dart';

/// Notification detail page — renders the full formatted content (rich text,
/// optional image, optional embedded YouTube video) of a single notification.
///
/// [adminMode] fetches via the admin endpoint (any notification in the
/// church, not just ones addressed to the current user) and shows an
/// "Editar" action.
class NotificationDetailPage extends StatefulWidget {
  const NotificationDetailPage({super.key, required this.id, this.adminMode = false});

  final String id;
  final bool adminMode;

  @override
  State<NotificationDetailPage> createState() => _NotificationDetailPageState();
}

class _NotificationDetailPageState extends State<NotificationDetailPage> {
  late final Dio _dio;
  bool _isLoading = true;
  String? _error;
  String _title = '';
  String _rawBody = '';
  String? _rawYoutubeUrl;
  DateTime? _createdAt;
  String? _imageUrl;
  QuillController? _quillController;
  YoutubePlayerController? _youtubeController;

  @override
  void initState() {
    super.initState();
    _dio = getIt<DioClient>().dio;
    _load();
  }

  @override
  void dispose() {
    _youtubeController?.close();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final path = widget.adminMode ? '/notifications/admin/${widget.id}' : '/notifications/${widget.id}';
      final resp = await _dio.get(path);
      final json = resp.data['notification'] as Map<String, dynamic>;
      final rawBody = json['body'] as String? ?? '';

      Document document;
      try {
        document = Document.fromJson(jsonDecode(rawBody) as List);
      } catch (_) {
        document = Document()..insert(0, rawBody);
      }

      final youtubeUrl = json['youtubeUrl'] as String?;
      final videoId = youtubeUrl != null
          ? YoutubePlayerController.convertUrlToId(youtubeUrl)
          : null;

      if (!mounted) return;
      setState(() {
        _title = json['title'] as String? ?? '';
        _rawBody = rawBody;
        _rawYoutubeUrl = youtubeUrl;
        _createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '')?.toLocal();
        _imageUrl = json['imageUrl'] as String?;
        _quillController = QuillController(
          document: document,
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
        _youtubeController = videoId != null
            ? YoutubePlayerController.fromVideoId(videoId: videoId)
            : null;
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = extractDioErrorMessage(e, fallback: 'Erro ao carregar notificação');
        _isLoading = false;
      });
    }
  }

  Future<void> _openEdit() async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AdminEditNotificationPage(
          id: widget.id,
          initialTitle: _title,
          initialBodyDelta: _rawBody,
          initialImageUrl: _imageUrl,
          initialYoutubeUrl: _rawYoutubeUrl,
        ),
      ),
    );
    if (updated == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Notificação'),
        actions: [
          if (widget.adminMode && !_isLoading && _error == null)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar',
              onPressed: _openEdit,
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
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePaddingH,
        vertical: AppSpacing.base,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(_title, style: AppTypography.titleLarge),
          if (_createdAt != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${_createdAt!.day.toString().padLeft(2, '0')}/${_createdAt!.month.toString().padLeft(2, '0')}/${_createdAt!.year}',
              style: AppTypography.labelSmall.copyWith(color: AppColors.grey400),
            ),
          ],
          if (_imageUrl != null) ...[
            const SizedBox(height: AppSpacing.base),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              child: Image.network(
                _imageUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
                loadingBuilder: (context, child, progress) => progress == null
                    ? child
                    : const Padding(
                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                        child: Center(child: CircularProgressIndicator()),
                      ),
              ),
            ),
          ],
          if (_youtubeController != null) ...[
            const SizedBox(height: AppSpacing.base),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: YoutubePlayer(controller: _youtubeController!),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.base),
          if (_quillController != null)
            QuillEditor.basic(
              controller: _quillController!,
              config: const QuillEditorConfig(
                scrollable: false,
                padding: EdgeInsets.zero,
                expands: false,
              ),
            ),
        ],
      ),
    );
  }
}
