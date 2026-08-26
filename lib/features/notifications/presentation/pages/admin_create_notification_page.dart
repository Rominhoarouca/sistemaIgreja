import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:image_picker/image_picker.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/utils/app_snackbar.dart';
import '../../../../injection/injection.dart';
import '../../../../shared/utils/plural.dart';

/// Admin-only screen to compose and send a notification, targeting a
/// specific user and/or role-based groups.
class AdminCreateNotificationPage extends StatefulWidget {
  const AdminCreateNotificationPage({super.key});

  @override
  State<AdminCreateNotificationPage> createState() =>
      _AdminCreateNotificationPageState();
}

class _AdminCreateNotificationPageState
    extends State<AdminCreateNotificationPage> {
  late final Dio _dio;
  final _titleCtrl = TextEditingController();
  final _youtubeCtrl = TextEditingController();
  final _userSearchCtrl = TextEditingController();
  final _quillController = QuillController.basic();
  // Hoisted (não criados a cada build): o editor reconstrói a cada tecla
  // digitada (listener do controller chama setState), e um FocusNode novo a
  // cada rebuild rouba o foco do anterior — impede digitar mais de 1 caractere.
  final _editorFocusNode = FocusNode();
  final _editorScrollController = ScrollController();

  final Set<String> _selectedGroups = {};
  List<_CellType> _cellTypes = [];
  String? _selectedCellTypeId;
  List<_Coordenacao> _coordenacoes = [];
  String? _selectedCoordenacaoId;

  final List<_UserOption> _selectedUsers = [];
  List<_UserOption> _userSearchResults = [];
  bool _isSearchingUsers = false;
  Timer? _searchDebounce;

  XFile? _pickedImage;
  Uint8List? _imageBytes;

  bool _isLoadingOptions = true;
  bool _isSending = false;

  static const _groupLabels = {
    'LEADERS': 'Líderes',
    'SUPERVISORS': 'Supervisores',
    'COORDENADORES': 'Coordenadores',
    'LEADERS_WITH_CELLS': 'Líderes com células',
    'LEADERS_WITHOUT_CELLS': 'Líderes sem células',
  };

  static const _groupIcons = {
    'LEADERS': Icons.person_outlined,
    'SUPERVISORS': Icons.manage_accounts_outlined,
    'COORDENADORES': Icons.account_tree_outlined,
    'LEADERS_WITH_CELLS': Icons.groups_outlined,
    'LEADERS_WITHOUT_CELLS': Icons.person_off_outlined,
  };

  @override
  void initState() {
    super.initState();
    _dio = getIt<DioClient>().dio;
    _loadTargetingOptions();
    // Re-evalua o botão de envio conforme título/corpo mudam.
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
    _userSearchCtrl.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadTargetingOptions() async {
    try {
      final results = await Future.wait([
        _dio.get('/cell-types'),
        _dio.get('/coordenacoes'),
      ]);
      final cellTypes = ((results[0].data['cellTypes'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .map(
            (j) => _CellType(id: j['id'] as String, name: j['name'] as String),
          )
          .toList();
      final coordenacoes = ((results[1].data['coordenacoes'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .map(
            (j) =>
                _Coordenacao(id: j['id'] as String, name: j['name'] as String),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _cellTypes = cellTypes;
        _coordenacoes = coordenacoes;
        _isLoadingOptions = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingOptions = false);
      AppSnackbar.error(
        extractDioErrorMessage(
          e,
          fallback: 'Erro ao carregar opções de público-alvo',
        ),
      );
    }
  }

  void _toggleGroup(String group) {
    setState(() {
      if (_selectedGroups.contains(group)) {
        _selectedGroups.remove(group);
      } else {
        _selectedGroups.add(group);
      }
    });
  }

  void _onUserSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _userSearchResults = [];
        _isSearchingUsers = false;
      });
      return;
    }
    setState(() => _isSearchingUsers = true);
    _searchDebounce = Timer(
      const Duration(milliseconds: 400),
      () => _searchUsers(query.trim()),
    );
  }

  Future<void> _searchUsers(String query) async {
    try {
      final resp = await _dio.get(
        '/users/search',
        queryParameters: {'q': query},
      );
      final results = ((resp.data['users'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .map(
            (j) => _UserOption(
              id: j['id'] as String,
              name: j['name'] as String,
              email: j['email'] as String,
            ),
          )
          .where((u) => !_selectedUsers.any((s) => s.id == u.id))
          .toList();
      if (!mounted) return;
      setState(() {
        _userSearchResults = results;
        _isSearchingUsers = false;
      });
    } on DioException {
      if (!mounted) return;
      setState(() => _isSearchingUsers = false);
    }
  }

  void _addUser(_UserOption user) {
    setState(() {
      _selectedUsers.add(user);
      _userSearchResults = [];
      _userSearchCtrl.clear();
    });
  }

  void _removeUser(_UserOption user) {
    setState(() => _selectedUsers.removeWhere((u) => u.id == user.id));
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() {
      _pickedImage = picked;
      _imageBytes = bytes;
    });
  }

  void _removeImage() {
    setState(() {
      _pickedImage = null;
      _imageBytes = null;
    });
  }

  bool get _hasTarget =>
      _selectedGroups.isNotEmpty ||
      _selectedCellTypeId != null ||
      _selectedCoordenacaoId != null ||
      _selectedUsers.isNotEmpty;

  bool get _canSubmit =>
      !_isSending &&
      _titleCtrl.text.trim().isNotEmpty &&
      _quillController.document.toPlainText().trim().isNotEmpty &&
      _hasTarget;

  Future<void> _send() async {
    final youtubeUrl = _youtubeCtrl.text.trim();
    if (youtubeUrl.isNotEmpty &&
        YoutubePlayerController.convertUrlToId(youtubeUrl) == null) {
      AppSnackbar.error('Link do YouTube inválido');
      return;
    }

    final groups = <Map<String, dynamic>>[
      for (final g in _selectedGroups) {'type': g},
      if (_selectedCellTypeId != null)
        {'type': 'CELL_TYPE', 'cellTypeId': _selectedCellTypeId},
      if (_selectedCoordenacaoId != null)
        {
          'type': 'COORDENACAO_LEADERS',
          'coordenacaoId': _selectedCoordenacaoId,
        },
    ];
    final userIds = _selectedUsers.map((u) => u.id).toList();
    final bodyDelta = jsonEncode(_quillController.document.toDelta().toJson());

    setState(() => _isSending = true);
    try {
      final data = _imageBytes != null
          ? FormData.fromMap({
              'title': _titleCtrl.text.trim(),
              'bodyDelta': bodyDelta,
              if (youtubeUrl.isNotEmpty) 'youtubeUrl': youtubeUrl,
              'userIds': jsonEncode(userIds),
              'groups': jsonEncode(groups),
              'image': MultipartFile.fromBytes(
                _imageBytes!,
                filename: _pickedImage!.name,
              ),
            })
          : {
              'title': _titleCtrl.text.trim(),
              'bodyDelta': bodyDelta,
              if (youtubeUrl.isNotEmpty) 'youtubeUrl': youtubeUrl,
              'userIds': jsonEncode(userIds),
              'groups': jsonEncode(groups),
            };

      final resp = await _dio.post('/notifications', data: data);
      final recipientCount = resp.data['recipientCount'] as int? ?? 0;
      if (!mounted) return;
      AppSnackbar.success(
        'Notificação enviada para ${plural(recipientCount, 'pessoa')}',
      );
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isSending = false);
      AppSnackbar.error(
        extractDioErrorMessage(e, fallback: 'Erro ao enviar notificação'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(elevation: 0, title: const Text('Nova notificação')),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: _isLoadingOptions
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                  const SizedBox(height: AppSpacing.xl),
                  Text('Público-alvo', style: AppTypography.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _groupLabels.entries
                        .map(
                          (entry) => _SelectableChip(
                            label: entry.value,
                            icon: _groupIcons[entry.key]!,
                            selected: _selectedGroups.contains(entry.key),
                            onTap: () => _toggleGroup(entry.key),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.base),
                  if (_cellTypes.isNotEmpty) ...[
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedCellTypeId,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de célula (opcional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Nenhum'),
                        ),
                        ..._cellTypes.map(
                          (t) => DropdownMenuItem(
                            value: t.id,
                            child: Text(t.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedCellTypeId = v),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (_coordenacoes.isNotEmpty) ...[
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedCoordenacaoId,
                      decoration: const InputDecoration(
                        labelText: 'Líderes de uma coordenação (opcional)',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Nenhuma'),
                        ),
                        ..._coordenacoes.map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _selectedCoordenacaoId = v),
                    ),
                    const SizedBox(height: AppSpacing.base),
                  ],
                  _buildUserSearch(),
                  const SizedBox(height: AppSpacing.xl2),
                  AppButton(
                    label: 'Enviar notificação',
                    isLoading: _isSending,
                    onPressed: _canSubmit ? _send : null,
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
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Image.memory(
              _imageBytes!,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
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
    return OutlinedButton.icon(
      onPressed: _pickImage,
      icon: const Icon(Icons.image_outlined),
      label: const Text('Adicionar imagem (opcional)'),
    );
  }

  Widget _buildUserSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Usuário específico (opcional)', style: AppTypography.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        AppSearchField(
          controller: _userSearchCtrl,
          hint: 'Buscar por nome ou e-mail...',
          onChanged: _onUserSearchChanged,
        ),
        if (_isSearchingUsers)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: LinearProgressIndicator(),
          ),
        if (_userSearchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: AppSpacing.xs),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.grey300),
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Column(
              children: _userSearchResults
                  .map(
                    (u) => ListTile(
                      dense: true,
                      title: Text(u.name),
                      subtitle: Text(u.email),
                      onTap: () => _addUser(u),
                      trailing: const Icon(Icons.add_circle_outline),
                    ),
                  )
                  .toList(),
            ),
          ),
        if (_selectedUsers.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _selectedUsers
                .map(
                  (u) => Chip(
                    label: Text(u.name),
                    onDeleted: () => _removeUser(u),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    avatar: Icon(icon, size: 16),
    selected: selected,
    onSelected: (_) => onTap(),
    selectedColor: AppColors.primary.withValues(alpha: 0.15),
    checkmarkColor: AppColors.primary,
    labelStyle: TextStyle(
      color: selected ? AppColors.primary : AppColors.textSecondary,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
    ),
    side: BorderSide(color: selected ? AppColors.primary : AppColors.grey300),
  );
}

class _CellType {
  final String id;
  final String name;
  _CellType({required this.id, required this.name});
}

class _Coordenacao {
  final String id;
  final String name;
  _Coordenacao({required this.id, required this.name});
}

class _UserOption {
  final String id;
  final String name;
  final String email;
  _UserOption({required this.id, required this.name, required this.email});
}
