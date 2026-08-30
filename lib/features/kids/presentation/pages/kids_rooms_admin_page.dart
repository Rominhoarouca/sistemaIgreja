import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../design_system/design_system.dart';
import '../../../../injection/injection.dart';
import '../../data/kids_models.dart';
import '../../data/kids_repository.dart';
import '../widgets/kids_widgets.dart';

/// Administração das salas: criar, editar capacidade/faixa etária e definir
/// quem são os professores. Só ADMIN chega aqui.
class KidsRoomsAdminPage extends StatefulWidget {
  const KidsRoomsAdminPage({super.key});

  @override
  State<KidsRoomsAdminPage> createState() => _KidsRoomsAdminPageState();
}

class _KidsRoomsAdminPageState extends State<KidsRoomsAdminPage> {
  late final KidsRepository _repo;
  late final Dio _dio;
  bool _loading = true;
  String? _error;
  List<KidsRoom> _rooms = [];

  @override
  void initState() {
    super.initState();
    _dio = getIt<Dio>();
    _repo = KidsRepository(_dio);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rooms = await _repo.listRooms();
      if (!mounted) return;
      setState(() {
        _rooms = rooms;
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

  Future<void> _editRoom({KidsRoom? room}) async {
    final data = await showModalBottomSheet<_RoomFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RoomFormSheet(room: room),
    );
    if (data == null || !mounted) return;

    try {
      if (room == null) {
        await _repo.createRoom(
          name: data.name,
          capacity: data.capacity,
          description: data.description,
          minAgeMonths: data.minAgeMonths,
          maxAgeMonths: data.maxAgeMonths,
        );
      } else {
        await _repo.updateRoom(
          room.id,
          name: data.name,
          capacity: data.capacity,
          description: data.description,
          minAgeMonths: data.minAgeMonths,
          maxAgeMonths: data.maxAgeMonths,
        );
      }
      if (mounted) _load();
    } on DioException catch (e) {
      if (!mounted) return;
      showKidsError(
        context,
        kidsErrorMessage(e, 'Não foi possível salvar a sala'),
      );
    }
  }

  Future<void> _editTeachers(KidsRoom room) async {
    final selected =
        await showModalBottomSheet<List<({String userId, String role})>>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _TeachersSheet(dio: _dio, room: room),
        );
    if (selected == null || !mounted) return;

    try {
      await _repo.setTeachers(room.id, selected);
      if (mounted) _load();
    } on DioException catch (e) {
      if (!mounted) return;
      showKidsError(
        context,
        kidsErrorMessage(e, 'Não foi possível salvar os professores'),
      );
    }
  }

  Future<void> _deactivate(KidsRoom room) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Desativar ${room.name}?'),
        content: const Text(
          'A sala some da lista dos professores. O histórico é preservado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Desativar'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await _repo.deactivateRoom(room.id);
      if (mounted) _load();
    } on DioException catch (e) {
      if (!mounted) return;
      showKidsError(context, kidsErrorMessage(e, 'Não foi possível desativar'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salas do Kids'),
        actions: [
          // O vínculo de professor só lista quem já tem conta; sem esta porta
          // não havia como cadastrar um professor novo a partir do Kids.
          IconButton(
            tooltip: 'Cadastrar professor',
            icon: const Icon(Icons.person_add_alt_outlined),
            onPressed: () async {
              await context.push(AppRoutes.adminUsersRegister);
              if (mounted) _load();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _editRoom(),
        icon: const Icon(Icons.add),
        label: const Text('Nova sala'),
      ),
      body: _loading
          ? const Center(child: AppLoadingIndicator(size: 32))
          : _error != null
          ? AppErrorState(message: _error!, onRetry: _load)
          : _rooms.isEmpty
          ? const Center(
              child: AppEmptyState(
                title: 'Nenhuma sala cadastrada',
                subtitle:
                    'Crie a primeira sala para começar a receber crianças.',
                icon: Icons.meeting_room_outlined,
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
                children: [
                  for (final room in _rooms)
                    _AdminRoomCard(
                      room: room,
                      onEdit: () => _editRoom(room: room),
                      onTeachers: () => _editTeachers(room),
                      onDeactivate: () => _deactivate(room),
                    ),
                  const SizedBox(height: AppSpacing.xl2),
                ],
              ),
            ),
    );
  }
}

class _AdminRoomCard extends StatelessWidget {
  const _AdminRoomCard({
    required this.room,
    required this.onEdit,
    required this.onTeachers,
    required this.onDeactivate,
  });

  final KidsRoom room;
  final VoidCallback onEdit;
  final VoidCallback onTeachers;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(room.name, style: AppTypography.titleSmall)),
              if (!room.isActive)
                const AppBadge(
                  label: 'Inativa',
                  variant: AppBadgeVariant.neutral,
                  size: AppBadgeSize.sm,
                ),
              PopupMenuButton<String>(
                onSelected: (value) => switch (value) {
                  'edit' => onEdit(),
                  'teachers' => onTeachers(),
                  'off' => onDeactivate(),
                  _ => null,
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Text('Editar sala'),
                  ),
                  const PopupMenuItem(
                    value: 'teachers',
                    child: Text('Professores'),
                  ),
                  if (room.isActive)
                    const PopupMenuItem(value: 'off', child: Text('Desativar')),
                ],
              ),
            ],
          ),
          Text(
            [
              '${room.capacity} lugares',
              if (room.ageRangeLabel.isNotEmpty) room.ageRangeLabel,
              if (room.description != null) room.description!,
            ].join(' · '),
            style: AppTypography.bodySmall.copyWith(color: mutedColor),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (room.teachers.isEmpty)
            // Sala sem professor não abre sessão nenhuma — o aviso evita a
            // descoberta disso no domingo de manhã.
            Row(
              children: [
                Icon(
                  Icons.warning_amber_outlined,
                  size: 14,
                  color: AppColors.error,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  'Sem professores vinculados',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final t in room.teachers)
                  AppBadge(
                    label: t.isTitular ? '${t.name} (titular)' : t.name,
                    variant: t.isTitular
                        ? AppBadgeVariant.primary
                        : AppBadgeVariant.neutral,
                    size: AppBadgeSize.sm,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RoomFormResult {
  const _RoomFormResult({
    required this.name,
    required this.capacity,
    this.description,
    this.minAgeMonths,
    this.maxAgeMonths,
  });

  final String name;
  final int capacity;
  final String? description;
  final int? minAgeMonths;
  final int? maxAgeMonths;
}

class _RoomFormSheet extends StatefulWidget {
  const _RoomFormSheet({this.room});

  final KidsRoom? room;

  @override
  State<_RoomFormSheet> createState() => _RoomFormSheetState();
}

class _RoomFormSheetState extends State<_RoomFormSheet> {
  late final _nameCtrl = TextEditingController(text: widget.room?.name ?? '');
  late final _capacityCtrl = TextEditingController(
    text: widget.room?.capacity.toString() ?? '',
  );
  late final _descCtrl = TextEditingController(
    text: widget.room?.description ?? '',
  );
  late final _minCtrl = TextEditingController(
    text: widget.room?.minAgeMonths?.toString() ?? '',
  );
  late final _maxCtrl = TextEditingController(
    text: widget.room?.maxAgeMonths?.toString() ?? '',
  );

  @override
  void dispose() {
    _nameCtrl.dispose();
    _capacityCtrl.dispose();
    _descCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.room == null ? 'Nova sala' : 'Editar sala',
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _nameCtrl,
                label: 'Nome',
                autofocus: true,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _capacityCtrl,
                label: 'Capacidade',
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _descCtrl,
                label: 'Descrição (opcional)',
              ),
              const SizedBox(height: AppSpacing.md),
              // Faixa etária em meses porque berçário distingue 6 de 18 meses.
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _minCtrl,
                      label: 'Idade mín. (meses)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppTextField(
                      controller: _maxCtrl,
                      label: 'Idade máx. (meses)',
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.base),
              AppButton(
                label: 'Salvar',
                onPressed: () {
                  final name = _nameCtrl.text.trim();
                  final capacity = int.tryParse(_capacityCtrl.text.trim()) ?? 0;
                  if (name.isEmpty || capacity <= 0) return;
                  Navigator.of(context).pop(
                    _RoomFormResult(
                      name: name,
                      capacity: capacity,
                      description: _descCtrl.text.trim(),
                      minAgeMonths: int.tryParse(_minCtrl.text.trim()),
                      maxAgeMonths: int.tryParse(_maxCtrl.text.trim()),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seleção de professores da sala. Busca usuários pela rota de admin já
/// existente — qualquer usuário pode ser professor, não só quem tem papel KIDS
/// (o pastor às vezes cobre uma sala).
class _TeachersSheet extends StatefulWidget {
  const _TeachersSheet({required this.dio, required this.room});

  final Dio dio;
  final KidsRoom room;

  @override
  State<_TeachersSheet> createState() => _TeachersSheetState();
}

class _TeachersSheetState extends State<_TeachersSheet> {
  final _searchCtrl = TextEditingController();
  late final Map<String, ({String name, String role})> _selected = {
    for (final t in widget.room.teachers)
      t.userId: (name: t.name, role: t.role),
  };
  List<({String id, String name, String email})> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final response = await widget.dio.get(
        '/users/search',
        queryParameters: {'q': query.trim()},
      );
      final users =
          (response.data as Map<String, dynamic>)['users'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _results = users
            .map(
              (u) => (
                id: (u as Map<String, dynamic>)['id'] as String,
                name: u['name'] as String? ?? '',
                email: u['email'] as String? ?? '',
              ),
            )
            .toList();
        _searching = false;
      });
    } on DioException {
      if (!mounted) return;
      setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.base),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Professores de ${widget.room.name}',
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              if (_selected.isNotEmpty) ...[
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final entry in _selected.entries)
                      InputChip(
                        label: Text(
                          entry.value.role == 'TITULAR'
                              ? '${entry.value.name} (titular)'
                              : entry.value.name,
                        ),
                        onDeleted: () =>
                            setState(() => _selected.remove(entry.key)),
                        onPressed: () => setState(() {
                          // Toque alterna titular/auxiliar — a sala precisa de
                          // alguém responsável, e trocar isso tem de ser fácil.
                          _selected[entry.key] = (
                            name: entry.value.name,
                            role: entry.value.role == 'TITULAR'
                                ? 'AUXILIAR'
                                : 'TITULAR',
                          );
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              AppTextField(
                controller: _searchCtrl,
                hint: 'Buscar usuário por nome ou e-mail',
                prefixIcon: Icons.search,
                onChanged: _search,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (_searching)
                const Center(child: AppLoadingIndicator())
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final user in _results)
                        ListTile(
                          title: Text(user.name),
                          subtitle: Text(user.email),
                          trailing: _selected.containsKey(user.id)
                              ? const Icon(Icons.check)
                              : const Icon(Icons.add),
                          onTap: () => setState(() {
                            if (_selected.containsKey(user.id)) {
                              _selected.remove(user.id);
                            } else {
                              _selected[user.id] = (
                                name: user.name,
                                role: 'AUXILIAR',
                              );
                            }
                          }),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: 'Salvar professores',
                onPressed: () => Navigator.of(context).pop([
                  for (final e in _selected.entries)
                    (userId: e.key, role: e.value.role),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
