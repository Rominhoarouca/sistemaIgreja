import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../../../injection/injection.dart';
import '../../../../shared/utils/app_snackbar.dart';
import '../../../auth/domain/entities/user_entity.dart';

/// Papéis que esta tela administra. SUPERADMIN fica de fora: é o dono do SaaS,
/// não um perfil da igreja — a API recusa mexer nele.
const _manageableRoles = [
  UserRole.admin,
  UserRole.coordinator,
  UserRole.supervisor,
  UserRole.leader,
  UserRole.kids,
  UserRole.responsavel,
];

class _ManagedUser {
  _ManagedUser({
    required this.id,
    required this.name,
    required this.email,
    required this.roles,
  });

  final String id;
  final String name;
  final String email;
  Set<UserRole> roles;

  factory _ManagedUser.fromJson(Map<String, dynamic> j) {
    final primary = UserRole.fromString(j['role'] as String? ?? 'LIDER');
    final extra = ((j['roles'] as List?) ?? const [])
        .map((r) => UserRole.fromString(r as String))
        .toSet();
    return _ManagedUser(
      id: j['id'] as String,
      name: j['name'] as String? ?? '',
      email: j['email'] as String? ?? '',
      roles: {primary, ...extra},
    );
  }

  /// Na ordem de precedência declarada em [UserRole].
  List<UserRole> get ordered =>
      UserRole.values.where(roles.contains).toList();

  String get initials => name
      .split(' ')
      .where((e) => e.isNotEmpty)
      .map((e) => e[0])
      .take(2)
      .join()
      .toUpperCase();
}

/// Adicionar/remover perfis de um usuário. Um mesmo usuário pode acumular
/// líder, supervisor, coordenador e admin.
class AdminUserRolesPage extends StatefulWidget {
  const AdminUserRolesPage({super.key});

  @override
  State<AdminUserRolesPage> createState() => _AdminUserRolesPageState();
}

class _AdminUserRolesPageState extends State<AdminUserRolesPage> {
  late final Dio _dio;
  final _searchCtrl = TextEditingController();

  List<_ManagedUser> _users = [];
  bool _loading = true;
  String? _error;
  String _query = '';
  String? _savingId;

  @override
  void initState() {
    super.initState();
    _dio = getIt<DioClient>().dio;
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await _dio.get('/users');
      final raw = (resp.data as Map<String, dynamic>)['users'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _users = raw
            .cast<Map<String, dynamic>>()
            .map(_ManagedUser.fromJson)
            .toList();
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Não foi possível carregar os usuários';
      });
    }
  }

  List<_ManagedUser> get _filtered {
    if (_query.trim().isEmpty) return _users;
    final q = _query.toLowerCase();
    return _users
        .where(
          (u) =>
              u.name.toLowerCase().contains(q) ||
              u.email.toLowerCase().contains(q),
        )
        .toList();
  }

  Future<void> _editRoles(_ManagedUser user) async {
    final result = await showModalBottomSheet<Set<UserRole>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RolesSheet(user: user),
    );
    if (result == null || !mounted) return;

    setState(() => _savingId = user.id);
    try {
      final resp = await _dio.patch(
        '/users/${user.id}/roles',
        data: {'roles': [for (final r in result) r.value]},
      );
      final updated = _ManagedUser.fromJson(
        (resp.data as Map<String, dynamic>)['user'] as Map<String, dynamic>,
      );
      if (!mounted) return;
      setState(() {
        final i = _users.indexWhere((u) => u.id == user.id);
        if (i >= 0) _users[i] = updated;
      });
      AppSnackbar.success('Perfis de ${user.name} atualizados');
    } on DioException catch (e) {
      if (!mounted) return;
      AppSnackbar.error(
        e.response?.data?['error']?['message'] as String? ??
            'Não foi possível salvar os perfis',
      );
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfis dos usuários')),
      body: _loading
          ? const Center(child: AppLoadingIndicator(size: 32))
          : _error != null
          ? AppErrorState(message: _error!, onRetry: _load)
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
                  child: AppSearchField(
                    hint: 'Buscar por nome ou e-mail...',
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                  ),
                ),
                Expanded(
                  child: _filtered.isEmpty
                      ? const AppEmptyState(
                          title: 'Nenhum usuário encontrado',
                          icon: Icons.person_search_outlined,
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.pagePaddingH,
                              0,
                              AppSpacing.pagePaddingH,
                              AppSpacing.xl2,
                            ),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) {
                              final user = _filtered[i];
                              return AppCard(
                                margin: const EdgeInsets.only(
                                  bottom: AppSpacing.sm,
                                ),
                                onTap: _savingId == null
                                    ? () => _editRoles(user)
                                    : null,
                                child: Row(
                                  children: [
                                    AppAvatar(initials: user.initials),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user.name,
                                            style: AppTypography.titleSmall,
                                          ),
                                          Text(
                                            user.email,
                                            style: AppTypography.bodySmall
                                                .copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                          ),
                                          const SizedBox(height: AppSpacing.xs),
                                          Wrap(
                                            spacing: AppSpacing.xs,
                                            runSpacing: AppSpacing.xs,
                                            children: [
                                              for (final role in user.ordered)
                                                AppBadge(
                                                  label: role.label,
                                                  size: AppBadgeSize.sm,
                                                  variant: role == UserRole.admin
                                                      ? AppBadgeVariant.primary
                                                      : AppBadgeVariant.neutral,
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_savingId == user.id)
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    else
                                      const Icon(Icons.chevron_right, size: 20),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }
}

/// Marcação dos perfis. Pelo menos um perfil precisa ficar marcado — a API
/// recusa uma lista vazia.
class _RolesSheet extends StatefulWidget {
  const _RolesSheet({required this.user});

  final _ManagedUser user;

  @override
  State<_RolesSheet> createState() => _RolesSheetState();
}

class _RolesSheetState extends State<_RolesSheet> {
  late final Set<UserRole> _selected = {...widget.user.roles};

  @override
  Widget build(BuildContext context) {
    // Um papel que a tela não administra (ex.: SUPERADMIN) não pode ser
    // desmarcado sem querer, então nem entra na lista nem no resultado.
    final canSave = _selected.any(_manageableRoles.contains);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.user.name, style: AppTypography.titleMedium),
            Text(
              'Marque todos os perfis que a pessoa exerce.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (final role in _manageableRoles)
              CheckboxListTile(
                dense: true,
                title: Text(role.label, style: AppTypography.bodyMedium),
                value: _selected.contains(role),
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    _selected.add(role);
                  } else {
                    _selected.remove(role);
                  }
                }),
                activeColor: AppColors.primary,
              ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canSave
                    ? () => Navigator.of(context).pop(
                        _selected.where(_manageableRoles.contains).toSet(),
                      )
                    : null,
                child: const Text('Salvar perfis'),
              ),
            ),
            if (!canSave)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Selecione pelo menos um perfil.',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
