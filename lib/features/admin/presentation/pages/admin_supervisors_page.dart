import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../../../core/network/auth_storage.dart';
import '../../../../core/network/dio_client.dart';
import '../../../../design_system/design_system.dart';
import '../../../../shared/widgets/reset_password_sheet.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────

class _SupervisorInfo {
  _SupervisorInfo({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.supervisorId,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String? supervisorId;
  String? coordenacaoId;
  String? coordenacaoName;
  String? coordenacaoColor;
  final List<_LeaderRef> leaders = [];

  String get initials => name
      .split(' ')
      .where((e) => e.isNotEmpty)
      .map((e) => e[0])
      .take(2)
      .join();

  factory _SupervisorInfo.fromJson(Map<String, dynamic> json) =>
      _SupervisorInfo(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        supervisorId: json['supervisorId'] as String?,
      );
}

class _LeaderRef {
  _LeaderRef({required this.id, required this.name, required this.email});

  final String id;
  final String name;
  final String email;

  String get initials => name
      .split(' ')
      .where((e) => e.isNotEmpty)
      .map((e) => e[0])
      .take(2)
      .join();

  factory _LeaderRef.fromJson(Map<String, dynamic> json) => _LeaderRef(
    id: json['id'] as String,
    name: json['name'] as String? ?? '',
    email: json['email'] as String? ?? '',
  );
}

class _CoordenacaoOption {
  _CoordenacaoOption({
    required this.id,
    required this.name,
    required this.color,
  });

  final String id;
  final String name;
  final String color;

  factory _CoordenacaoOption.fromJson(Map<String, dynamic> json) =>
      _CoordenacaoOption(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        color: json['color'] as String? ?? '#607D8B',
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Page
// ─────────────────────────────────────────────────────────────────────────────

class AdminSupervisorsPage extends StatefulWidget {
  const AdminSupervisorsPage({super.key});

  @override
  State<AdminSupervisorsPage> createState() => _AdminSupervisorsPageState();
}

class _AdminSupervisorsPageState extends State<AdminSupervisorsPage> {
  late final Dio _dio;
  bool _loading = true;
  String? _error;
  List<_SupervisorInfo> _supervisors = [];
  List<_LeaderRef> _allLeaders = [];
  List<_CoordenacaoOption> _coordenacoes = [];

  @override
  void initState() {
    super.initState();
    _dio = DioClient(AuthStorage()).dio;
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _dio.get('/users/supervisors'),
        _dio.get('/users/leaders'),
        _dio.get('/coordenacoes'),
      ]);

      final supervisorList =
          ((results[0].data as Map<String, dynamic>)['supervisors'] as List)
              .cast<Map<String, dynamic>>();
      final leaderList =
          ((results[1].data as Map<String, dynamic>)['leaders'] as List)
              .cast<Map<String, dynamic>>();
      final coordenacaoList =
          ((results[2].data as Map<String, dynamic>)['coordenacoes'] as List)
              .cast<Map<String, dynamic>>();

      final allLeaders = leaderList.map(_LeaderRef.fromJson).toList();
      final coordenacoes = coordenacaoList
          .map(_CoordenacaoOption.fromJson)
          .toList();

      // Build supervisor info enriched with their leaders and coordenacao
      final supervisors = supervisorList
          .map((s) => _SupervisorInfo.fromJson(s))
          .toList();

      for (final sup in supervisors) {
        sup.leaders.addAll(allLeaders.where((l) => l.id == sup.id).toList());
        // leaders whose supervisorId == sup.id
        final myLeaders = allLeaders.where((l) {
          final raw = leaderList.firstWhere(
            (m) => m['id'] == l.id,
            orElse: () => <String, dynamic>{},
          );
          return raw['supervisorId'] == sup.id;
        }).toList();
        sup.leaders.clear();
        sup.leaders.addAll(myLeaders);

        final coordId =
            supervisorList.firstWhere(
                  (m) => m['id'] == sup.id,
                  orElse: () => {},
                )['coordenacaoId']
                as String?;
        if (coordId != null) {
          final coordMatch = coordenacoes
              .cast<_CoordenacaoOption?>()
              .firstWhere((c) => c?.id == coordId, orElse: () => null);
          if (coordMatch != null) {
            sup.coordenacaoId = coordMatch.id;
            sup.coordenacaoName = coordMatch.name;
            sup.coordenacaoColor = coordMatch.color;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _supervisors = supervisors;
        _allLeaders = allLeaders;
        _coordenacoes = coordenacoes;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error =
            e.response?.data?['error']?['message'] as String? ??
            'Erro ao carregar supervisores';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Supervisores'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loading ? null : _loadData,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.base),
                  AppButton(
                    label: 'Tentar novamente',
                    variant: AppButtonVariant.outline,
                    isFullWidth: false,
                    onPressed: _loadData,
                  ),
                ],
              ),
            )
          : _supervisors.isEmpty
          ? const AppEmptyState(
              title: 'Nenhum supervisor',
              subtitle: 'Promova um líder a supervisor na tela de Líderes.',
              icon: Icons.manage_accounts_outlined,
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
                itemCount: _supervisors.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (_, i) => _SupervisorCard(
                  supervisor: _supervisors[i],
                  allLeaders: _allLeaders,
                  coordenacoes: _coordenacoes,
                  dio: _dio,
                  onUpdated: _loadData,
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateSupervisorSheet,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Novo Supervisor'),
      ),
    );
  }

  void _showCreateSupervisorSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateUserSheet(
        dio: _dio,
        role: 'SUPERVISOR',
        roleLabel: 'Supervisor',
        onCreated: _loadData,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Supervisor Card
// ─────────────────────────────────────────────────────────────────────────────

class _SupervisorCard extends StatelessWidget {
  const _SupervisorCard({
    required this.supervisor,
    required this.allLeaders,
    required this.coordenacoes,
    required this.dio,
    required this.onUpdated,
  });

  final _SupervisorInfo supervisor;
  final List<_LeaderRef> allLeaders;
  final List<_CoordenacaoOption> coordenacoes;
  final Dio dio;
  final VoidCallback onUpdated;

  Color get _coordColor {
    final hex = supervisor.coordenacaoColor;
    if (hex == null) return AppColors.grey300;
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppColors.grey300;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppAvatar(initials: supervisor.initials),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(supervisor.name, style: AppTypography.titleSmall),
                    Text(
                      supervisor.email,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    if (supervisor.coordenacaoName != null)
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: _coordColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          Text(
                            supervisor.coordenacaoName!,
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      )
                    else
                      Text(
                        'Sem coordenação',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'leaders',
                    child: Text('Gerenciar líderes'),
                  ),
                  const PopupMenuItem(
                    value: 'coordenacao',
                    child: Text('Vincular coordenação'),
                  ),
                  const PopupMenuItem(
                    value: 'password',
                    child: Text('Redefinir senha'),
                  ),
                ],
                onSelected: (action) {
                  if (action == 'leaders') {
                    _showLeaderSheet(context);
                  } else if (action == 'coordenacao') {
                    _showCoordenacaoSheet(context);
                  } else if (action == 'password') {
                    showResetPasswordSheet(
                      context,
                      userId: supervisor.id,
                      userName: supervisor.name,
                    );
                  }
                },
              ),
            ],
          ),
          if (supervisor.leaders.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: supervisor.leaders
                  .map(
                    (l) => Chip(
                      avatar: CircleAvatar(
                        radius: 10,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.15,
                        ),
                        child: Text(
                          l.initials,
                          style: AppTypography.labelSmall.copyWith(
                            color: AppColors.primary,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      label: Text(l.name, style: AppTypography.labelSmall),
                      backgroundColor: AppColors.primary.withValues(
                        alpha: 0.07,
                      ),
                      side: BorderSide.none,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
          ] else ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Nenhum líder vinculado',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showLeaderSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ManageLeadersSheet(
        supervisor: supervisor,
        allLeaders: allLeaders,
        dio: dio,
        onSaved: onUpdated,
      ),
    );
  }

  void _showCoordenacaoSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AssignCoordenacaoSheet(
        supervisor: supervisor,
        coordenacoes: coordenacoes,
        dio: dio,
        onSaved: onUpdated,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet: Manage Leaders
// ─────────────────────────────────────────────────────────────────────────────

class _ManageLeadersSheet extends StatefulWidget {
  const _ManageLeadersSheet({
    required this.supervisor,
    required this.allLeaders,
    required this.dio,
    required this.onSaved,
  });

  final _SupervisorInfo supervisor;
  final List<_LeaderRef> allLeaders;
  final Dio dio;
  final VoidCallback onSaved;

  @override
  State<_ManageLeadersSheet> createState() => _ManageLeadersSheetState();
}

class _ManageLeadersSheetState extends State<_ManageLeadersSheet> {
  bool _saving = false;

  Future<void> _toggle(_LeaderRef leader, bool assign) async {
    setState(() => _saving = true);
    try {
      await widget.dio.patch(
        '/users/leaders/${leader.id}/supervisor',
        data: {'supervisorId': assign ? widget.supervisor.id : null},
      );
      if (!mounted) return;
      widget.onSaved();
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?['message'] as String? ??
                'Erro ao atualizar líder',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final myLeaderIds = widget.supervisor.leaders.map((l) => l.id).toSet();

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) => Padding(
        padding: const EdgeInsets.fromLTRB(0, AppSpacing.base, 0, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePaddingH,
              ),
              child: Text(
                'Líderes — ${widget.supervisor.name}',
                style: AppTypography.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (_saving) const LinearProgressIndicator(),
            Expanded(
              child: widget.allLeaders.isEmpty
                  ? const Center(child: Text('Nenhum líder disponível'))
                  : ListView.builder(
                      controller: scrollCtrl,
                      itemCount: widget.allLeaders.length,
                      itemBuilder: (_, i) {
                        final leader = widget.allLeaders[i];
                        final assigned = myLeaderIds.contains(leader.id);
                        return CheckboxListTile(
                          value: assigned,
                          title: Text(leader.name),
                          subtitle: Text(leader.email),
                          onChanged: _saving
                              ? null
                              : (v) => _toggle(leader, v ?? false),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sheet: Assign Coordenacao
// ─────────────────────────────────────────────────────────────────────────────

class _AssignCoordenacaoSheet extends StatefulWidget {
  const _AssignCoordenacaoSheet({
    required this.supervisor,
    required this.coordenacoes,
    required this.dio,
    required this.onSaved,
  });

  final _SupervisorInfo supervisor;
  final List<_CoordenacaoOption> coordenacoes;
  final Dio dio;
  final VoidCallback onSaved;

  @override
  State<_AssignCoordenacaoSheet> createState() =>
      _AssignCoordenacaoSheetState();
}

class _AssignCoordenacaoSheetState extends State<_AssignCoordenacaoSheet> {
  late String? _selected;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.supervisor.coordenacaoId;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await widget.dio.patch(
        '/users/supervisors/${widget.supervisor.id}/coordenacao',
        data: {'coordenacaoId': _selected},
      );
      if (!mounted) return;
      widget.onSaved();
      Navigator.of(context).pop();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?['message'] as String? ??
                'Erro ao salvar coordenação',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePaddingH,
        AppSpacing.base,
        AppSpacing.pagePaddingH,
        AppSpacing.base + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          Text('Vincular Coordenação', style: AppTypography.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.supervisor.name,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.base),
          // None option
          RadioListTile<String?>(
            title: const Text('Sem coordenação'),
            value: null,
            groupValue: _selected,
            onChanged: (v) => setState(() => _selected = v),
          ),
          ...widget.coordenacoes.map((c) {
            Color chipColor;
            try {
              chipColor = Color(int.parse(c.color.replaceFirst('#', '0xFF')));
            } catch (_) {
              chipColor = AppColors.primary;
            }
            return RadioListTile<String?>(
              title: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: chipColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Text(c.name),
                ],
              ),
              value: c.id,
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v),
            );
          }),
          const SizedBox(height: AppSpacing.base),
          AppButton(
            label: 'Salvar',
            isLoading: _saving,
            onPressed: _save,
            prefixIcon: Icons.save_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Create User Sheet (Supervisor / Coordenador)
// ─────────────────────────────────────────────────────────────────────────────

class _CreateUserSheet extends StatefulWidget {
  const _CreateUserSheet({
    required this.dio,
    required this.role,
    required this.roleLabel,
    required this.onCreated,
  });

  final Dio dio;
  final String role;
  final String roleLabel;
  final VoidCallback onCreated;

  @override
  State<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends State<_CreateUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await widget.dio.post(
        '/users/create',
        data: {
          'name': _nameCtrl.text.trim(),
          'email': _emailCtrl.text.trim(),
          'password': _passwordCtrl.text,
          'role': widget.role,
        },
      );
      if (!mounted) return;
      widget.onCreated();
      Navigator.of(context).pop();
      final rootCtx = Navigator.of(context, rootNavigator: true).context;
      ScaffoldMessenger.maybeOf(rootCtx)?.showSnackBar(
        SnackBar(
          content: Text('${widget.roleLabel} cadastrado com sucesso!'),
          backgroundColor: AppColors.success,
        ),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      final rootCtx = Navigator.of(context, rootNavigator: true).context;
      ScaffoldMessenger.maybeOf(rootCtx)?.showSnackBar(
        SnackBar(
          content: Text(
            e.response?.data?['error']?['message'] as String? ??
                'Erro ao cadastrar ${widget.roleLabel.toLowerCase()}',
          ),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePaddingH,
        AppSpacing.base,
        AppSpacing.pagePaddingH,
        AppSpacing.base + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            Text('Novo ${widget.roleLabel}', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Preencha os dados para cadastrar um(a) ${widget.roleLabel.toLowerCase()}.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            AppTextField(
              controller: _nameCtrl,
              label: 'Nome completo',
              hint: 'Nome do ${widget.roleLabel.toLowerCase()}',
              prefixIcon: Icons.person_outline,
              textInputAction: TextInputAction.next,
              validator: (v) => (v == null || v.trim().length < 2)
                  ? 'Nome obrigatório'
                  : null,
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _emailCtrl,
              label: 'E-mail',
              hint: 'email@exemplo.com',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'E-mail obrigatório';
                if (!v.contains('@')) return 'E-mail inválido';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              controller: _passwordCtrl,
              label: 'Senha',
              hint: 'Mínimo 6 caracteres',
              prefixIcon: Icons.lock_outline,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              validator: (v) => (v == null || v.length < 6)
                  ? 'Senha mínimo 6 caracteres'
                  : null,
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 16,
                ),
                label: Text(
                  _obscurePassword ? 'Mostrar senha' : 'Ocultar senha',
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.base),
            AppButton(
              label: 'Cadastrar ${widget.roleLabel}',
              isLoading: _saving,
              onPressed: _save,
              prefixIcon: Icons.save_outlined,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}
