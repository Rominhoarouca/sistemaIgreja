import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/app_snackbar.dart';
import '../../../../injection/injection.dart';

/// Admin-only screen to edit an already-sent notification's content
/// (title, body, image, YouTube link). Audience/recipients are fixed at
/// send time and are not editable here.
class AdminEditNotificationPage extends StatefulWidget {
  const AdminEditNotificationPage({
    super.key,
    required this.id,
    required this.initialTitle,
    required this.initialBodyDelta,
    this.initialImageUrl,
    this.initialYoutubeUrl,
  });

  final String id;
  final String initialTitle;
  final String initialBodyDelta;
  final String? initialImageUrl;
  final String? initialYoutubeUrl;

  @override
  State<AdminEditNotificationPage> createState() => _AdminEditNotificationPageState();
}

class _AdminEditNotificationPageState extends State<AdminEditNotificationPage> {
  late final Dio _dio;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _youtubeCtrl;
  late final QuillController _quillController;
  final _editorFocusNode = FocusNode();
  final _editorScrollController = ScrollController();

  String? _existingImageUrl;
  bool _imageRemoved = false;
  XFile? _pickedImage;
  Uint8List? _imageBytes;

  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _dio = getIt<DioClient>().dio;
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _youtubeCtrl = TextEditingController(text: widget.initialYoutubeUrl ?? '');
    _existingImageUrl = widget.initialImageUrl;

    Document document;
    try {
      document = Document.fromJson(jsonDecode(widget.initialBodyDelta) as List);
    } catch (_) {
      document = Document()..insert(0, widget.initialBodyDelta);
    }
    _quillController = QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _titleCtrl.addListener(_refreshSubmitState);
    _quillController.addListener(_refreshSubmitState);
  }

  void _refreshSubmitState() => setState(() {});

  @override
  void dispose() {
    _titleCtrl.removeListener(_refreshSubmitState);
    _quillController.removeListener(_refreshSubmitState);
    _titleCtrl.dispose();
    _youtubeCtrl.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedImage = picked;
      _imageBytes = bytes;
      _imageRemoved = false;
    });
  }

  void _removeImage() {
    setState(() {
      _pickedImage = null;
      _imageBytes = null;
      _existingImageUrl = null;
      _imageRemoved = true;
    });
  }

  bool get _canSubmit =>
      !_isSending &&
      _titleCtrl.text.trim().isNotEmpty &&
      _quillController.document.toPlainText().trim().isNotEmpty;

  Future<void> _save() async {
    final youtubeUrl = _youtubeCtrl.text.trim();
    final bodyDelta = jsonEncode(_quillController.document.toDelta().toJson());

    setState(() => _isSending = true);
    try {
      final data = _imageBytes != null
          ? FormData.fromMap({
              'title': _titleCtrl.text.trim(),
              'bodyDelta': bodyDelta,
              if (youtubeUrl.isNotEmpty) 'youtubeUrl': youtubeUrl,
              'image': MultipartFile.fromBytes(_imageBytes!, filename: _pickedImage!.name),
            })
          : {
              'title': _titleCtrl.text.trim(),
              'bodyDelta': bodyDelta,
              if (youtubeUrl.isNotEmpty) 'youtubeUrl': youtubeUrl,
              if (_imageRemoved) 'removeImage': 'true',
            };

      await _dio.patch('/notifications/admin/${widget.id}', data: data);
      if (!mounted) return;
      AppSnackbar.success('Notificação atualizada');
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      AppSnackbar.error(extractDioErrorMessage(e, fallback: 'Erro ao atualizar notificação'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Editar notificação')),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTextField(controller: _titleCtrl, label: 'Título'),
            const SizedBox(height: AppSpacing.base),
            Text('Conteúdo', style: AppTypography.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            _buildQuillEditor(),
            const SizedBox(height: AppSpacing.base),
            _buildImageSection(),
            const SizedBox(height: AppSpacing.base),
            AppTextField(
              controller: _youtubeCtrl,
              label: 'Link do YouTube (opcional)',
              hint: 'https://youtube.com/watch?v=...',
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: AppSpacing.xl2),
            AppButton(
              label: 'Salvar alterações',
              isLoading: _isSending,
              onPressed: _canSubmit ? _save : null,
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildQuillEditor() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(color: AppColors.grey300),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          QuillSimpleToolbar(controller: _quillController),
          const Divider(height: 1),
          Container(
            height: 220,
            padding: const EdgeInsets.all(AppSpacing.sm),
            color: AppColors.white,
            child: QuillEditor.basic(
              controller: _quillController,
              focusNode: _editorFocusNode,
              scrollController: _editorScrollController,
              config: const QuillEditorConfig(scrollable: true, expands: true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection() {
    if (_imageBytes != null) {
      return _imagePreview(Image.memory(_imageBytes!, height: 160, width: double.infinity, fit: BoxFit.cover));
    }
    if (!_imageRemoved && _existingImageUrl != null) {
      return _imagePreview(
        Image.network(_existingImageUrl!, height: 160, width: double.infinity, fit: BoxFit.cover),
      );
    }
    return OutlinedButton.icon(
      onPressed: _pickImage,
      icon: const Icon(Icons.image_outlined),
      label: const Text('Adicionar imagem (opcional)'),
    );
  }

  Widget _imagePreview(Widget image) {
    return Stack(
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(AppSpacing.radiusMd), child: image),
        Positioned(
          top: AppSpacing.xs,
          right: AppSpacing.xs,
          child: IconButton(
            icon: const Icon(Icons.close, color: AppColors.white),
            style: IconButton.styleFrom(backgroundColor: Colors.black45),
            onPressed: _removeImage,
          ),
        ),
      ],
    );
  }
}
