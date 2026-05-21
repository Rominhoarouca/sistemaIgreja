import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../design_system/design_system.dart';
import '../bloc/auth_bloc.dart';

/// Profile page — view and edit user profile, including photo, contact info,
/// birth date, and list of children.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();

  File? _photoFile;
  DateTime? _birthDate;
  bool _editing = false;
  bool _saving = false;

  final List<Map<String, dynamic>> _children = [];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final source = await _showPhotoSourceSheet();
    if (source == null) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Ajustar foto',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
          showCropGrid: true,
        ),
        IOSUiSettings(
          title: 'Ajustar foto',
          aspectRatioLockEnabled: false,
          showCancelConfirmationDialog: true,
          rotateButtonsHidden: false,
          resetButtonHidden: false,
        ),
      ],
    );

    if (cropped != null && mounted) {
      setState(() => _photoFile = File(cropped.path));
    }
  }

  Future<ImageSource?> _showPhotoSourceSheet() {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
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
            ListTile(
              leading: const Icon(
                Icons.camera_alt_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Tirar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_outlined,
                color: AppColors.primary,
              ),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: AppSpacing.base),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Data de nascimento',
    );
    if (picked != null && mounted) setState(() => _birthDate = picked);
  }

  void _addChild() => _showChildDialog(null, null);
  void _editChild(int index) => _showChildDialog(index, _children[index]);

  void _showChildDialog(int? index, Map<String, dynamic>? existing) {
    final nameCtrl = TextEditingController(
      text: existing?['name'] as String? ?? '',
    );
    DateTime? childDob = existing?['birthDate'] as DateTime?;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(index == null ? 'Adicionar filho(a)' : 'Editar filho(a)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Nome'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.base),
              InkWell(
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: childDob ?? DateTime(now.year - 5),
                    firstDate: DateTime(2000),
                    lastDate: now,
                  );
                  if (picked != null) setDlgState(() => childDob = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Nascimento (opcional)',
                  ),
                  child: Text(
                    childDob != null
                        ? DateFormat('dd/MM/yyyy').format(childDob!)
                        : 'Selecionar',
                    style: AppTypography.bodyMedium,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            if (index != null)
              TextButton(
                onPressed: () {
                  setState(() => _children.removeAt(index));
                  Navigator.pop(ctx);
                },
                child: Text(
                  'Remover',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            TextButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                setState(() {
                  final entry = <String, dynamic>{
                    if (existing?['id'] != null) 'id': existing!['id'],
                    'name': nameCtrl.text.trim(),
                    if (childDob != null) 'birthDate': childDob,
                  };
                  if (index == null) {
                    _children.add(entry);
                  } else {
                    _children[index] = entry;
                  }
                });
                Navigator.pop(ctx);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    // TODO: call API PATCH /v1/users/me
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() {
      _saving = false;
      _editing = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Perfil atualizado com sucesso!'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sair da conta'),
        content: const Text('Tem certeza que deseja sair?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.read<AuthBloc>().add(const AuthLogoutRequested());
            },
            child: Text('Sair', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthUnauthenticated) context.go(AppRoutes.login);
      },
      builder: (context, state) {
        final user = state is AuthAuthenticated ? state.user : null;
        final initials = user != null
            ? user.name.split(' ').map((e) => e[0]).take(2).join()
            : 'US';
        final roleLabel = user?.role.value == AppConstants.roleAdmin
            ? 'Administrador'
            : 'Líder';

        if (_editing && _nameCtrl.text.isEmpty && user != null) {
          _nameCtrl.text = user.name;
        }

        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppColors.primary,
            foregroundColor: AppColors.white,
            title: const Text('Meu Perfil'),
            actions: [
              if (!_editing)
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Editar perfil',
                  onPressed: () => setState(() => _editing = true),
                )
              else
                TextButton(
                  onPressed: () => setState(() => _editing = false),
                  child: const Text(
                    'Cancelar',
                    style: TextStyle(color: AppColors.white),
                  ),
                ),
            ],
          ),
          backgroundColor: AppColors.background,
          body: Form(
            key: _formKey,
            child: ListView(
              children: [
                // Header with photo
                Container(
                  width: double.infinity,
                  color: AppColors.primary,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePaddingH,
                    0,
                    AppSpacing.pagePaddingH,
                    AppSpacing.xl2,
                  ),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: _editing ? _pickPhoto : null,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 44,
                              backgroundColor: AppColors.primaryLight,
                              backgroundImage: _photoFile != null
                                  ? FileImage(_photoFile!)
                                  : null,
                              child: _photoFile == null
                                  ? Text(
                                      initials,
                                      style: AppTypography.headlineMedium
                                          .copyWith(color: AppColors.primary),
                                    )
                                  : null,
                            ),
                            if (_editing)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppColors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.base),
                      if (_editing)
                        TextButton.icon(
                          onPressed: _pickPhoto,
                          icon: const Icon(
                            Icons.photo_camera_outlined,
                            color: AppColors.white,
                          ),
                          label: const Text(
                            'Alterar foto',
                            style: TextStyle(color: AppColors.white),
                          ),
                        )
                      else ...[
                        Text(
                          user?.name ?? 'Usuário',
                          style: AppTypography.headlineSmall.copyWith(
                            color: AppColors.white,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          user?.email ?? '',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.white.withValues(alpha: 0.8),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        AppBadge(
                          label: roleLabel,
                          variant: AppBadgeVariant.info,
                        ),
                      ],
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_editing) ...[
                        AppSectionHeader(title: 'Informações pessoais'),
                        const SizedBox(height: AppSpacing.base),
                        AppCard(
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Nome completo',
                                ),
                                textCapitalization: TextCapitalization.words,
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty)
                                    ? 'Nome obrigatório'
                                    : null,
                              ),
                              const SizedBox(height: AppSpacing.base),
                              TextFormField(
                                controller: _phoneCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Telefone',
                                ),
                                keyboardType: TextInputType.phone,
                              ),
                              const SizedBox(height: AppSpacing.base),
                              TextFormField(
                                controller: _addressCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Endereço',
                                ),
                                textCapitalization:
                                    TextCapitalization.sentences,
                                maxLines: 2,
                              ),
                              const SizedBox(height: AppSpacing.base),
                              InkWell(
                                onTap: _pickBirthDate,
                                child: InputDecorator(
                                  decoration: const InputDecoration(
                                    labelText: 'Data de nascimento',
                                    suffixIcon: Icon(
                                      Icons.calendar_today_outlined,
                                    ),
                                  ),
                                  child: Text(
                                    _birthDate != null
                                        ? DateFormat(
                                            'dd/MM/yyyy',
                                          ).format(_birthDate!)
                                        : 'Selecionar data',
                                    style: AppTypography.bodyMedium,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xl),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AppSectionHeader(title: 'Filhos'),
                            TextButton.icon(
                              onPressed: _addChild,
                              icon: const Icon(Icons.add),
                              label: const Text('Adicionar'),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.sm),

                        if (_children.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.base,
                            ),
                            child: Center(
                              child: Text(
                                'Nenhum filho cadastrado',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          )
                        else
                          AppCard(
                            padding: EdgeInsets.zero,
                            child: Column(
                              children: _children.asMap().entries.map((entry) {
                                final i = entry.key;
                                final child = entry.value;
                                final dob = child['birthDate'] as DateTime?;
                                return Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (i > 0) const Divider(height: 1),
                                    ListTile(
                                      leading: const Icon(
                                        Icons.child_care_outlined,
                                        color: AppColors.primary,
                                      ),
                                      title: Text(
                                        child['name'] as String,
                                        style: AppTypography.bodyMedium,
                                      ),
                                      subtitle: dob != null
                                          ? Text(
                                              DateFormat(
                                                'dd/MM/yyyy',
                                              ).format(dob),
                                              style: AppTypography.bodySmall
                                                  .copyWith(
                                                    color:
                                                        AppColors.textSecondary,
                                                  ),
                                            )
                                          : null,
                                      trailing: IconButton(
                                        icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 18,
                                        ),
                                        onPressed: () => _editChild(i),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),

                        const SizedBox(height: AppSpacing.xl2),

                        AppButton(
                          label: _saving ? 'Salvando...' : 'Salvar alterações',
                          prefixIcon: Icons.save_outlined,
                          onPressed: _saving ? null : _saveProfile,
                        ),

                        const SizedBox(height: AppSpacing.xl),
                      ],

                      // Account options (always visible)
                      if (!_editing) ...[
                        const SizedBox(height: AppSpacing.base),
                        AppCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(
                                  Icons.lock_outline,
                                  color: AppColors.primary,
                                ),
                                title: const Text('Alterar senha'),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.grey400,
                                ),
                                onTap: () => context.push('/change-password'),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(
                                  Icons.notifications_outlined,
                                  color: AppColors.primary,
                                ),
                                title: const Text('Notificações'),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.grey400,
                                ),
                                onTap: () => context.push('/notifications'),
                              ),
                              const Divider(height: 1),
                              ListTile(
                                leading: const Icon(
                                  Icons.info_outline,
                                  color: AppColors.primary,
                                ),
                                title: const Text('Sobre o app'),
                                trailing: const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.grey400,
                                ),
                                onTap: () => context.push('/about'),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.xl),

                      AppButton(
                        label: 'Sair da conta',
                        variant: AppButtonVariant.danger,
                        prefixIcon: Icons.logout,
                        onPressed: () => _confirmLogout(context),
                      ),

                      const SizedBox(height: AppSpacing.xl2),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
