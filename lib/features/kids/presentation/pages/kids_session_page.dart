import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../design_system/design_system.dart';
import '../../../../injection/injection.dart';
import '../../data/kids_models.dart';
import '../../data/kids_repository.dart';
import '../widgets/kids_widgets.dart';
import 'kids_quick_register_page.dart';
import 'kids_scan_page.dart';

/// A sala durante o culto: quem está dentro, quem já saiu, anotações e alertas.
class KidsSessionPage extends StatefulWidget {
  const KidsSessionPage({super.key, required this.sessionId});

  final String sessionId;

  @override
  State<KidsSessionPage> createState() => _KidsSessionPageState();
}

class _KidsSessionPageState extends State<KidsSessionPage> {
  late final KidsRepository _repo;
  bool _loading = true;
  String? _error;
  KidsSession? _session;
  List<KidsCheckin> _checkins = [];
  List<KidsNote> _notes = [];

  @override
  void initState() {
    super.initState();
    _repo = KidsRepository(getIt<Dio>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _repo.getSession(widget.sessionId);
      if (!mounted) return;
      setState(() {
        _session = data.session;
        _checkins = data.checkins;
        _notes = data.notes;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = kidsErrorMessage(e, 'Erro ao carregar a sala');
        _loading = false;
      });
    }
  }

  List<KidsCheckin> get _present =>
      _checkins.where((c) => c.isPresent).toList();
  List<KidsCheckin> get _gone => _checkins.where((c) => !c.isPresent).toList();

  // ── Check-in ──────────────────────────────────────────────────────────────

  Future<void> _checkInByQr() async {
    final token = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const KidsScanPage(title: 'Ler QR do responsável'),
      ),
    );
    if (token == null || !mounted) return;

    try {
      final children = await _repo.resolveQr(token);
      if (!mounted) return;

      final selected = await showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _ChildPickerSheet(children: children),
      );
      if (selected == null || selected.isEmpty || !mounted) return;

      await _confirmCheckIn(selected, method: 'QR');
    } on DioException catch (e) {
      if (!mounted) return;
      showKidsError(context, kidsErrorMessage(e, 'QR Code inválido'));
    }
  }

  Future<void> _checkInBySearch() async {
    final childId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SearchChildSheet(repo: _repo),
    );
    if (childId == null || !mounted) return;
    await _confirmCheckIn([childId], method: 'MANUAL');
  }

  Future<void> _quickRegister() async {
    final child = await Navigator.of(context).push<KidsChild>(
      MaterialPageRoute(builder: (_) => const KidsQuickRegisterPage()),
    );
    if (child == null || !mounted) return;
    await _confirmCheckIn([child.id], method: 'MANUAL');
  }

  Future<void> _confirmCheckIn(
    List<String> childIds, {
    required String method,
  }) async {
    try {
      final result = await _repo.checkIn(
        sessionId: widget.sessionId,
        childIds: childIds,
        method: method,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => KidsPickupCodeDialog(
          results: result.checkins,
          roomName: _session?.roomName ?? '',
        ),
      );
      if (mounted) _load();
    } on DioException catch (e) {
      if (!mounted) return;
      showKidsError(
        context,
        kidsErrorMessage(e, 'Não foi possível fazer o check-in'),
      );
    }
  }

  // ── Check-out ─────────────────────────────────────────────────────────────

  Future<void> _checkOut(KidsCheckin checkin) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            Text(
              'Retirar ${checkin.childName}',
              style: AppTypography.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Ler QR do responsável'),
              onTap: () => Navigator.of(ctx).pop('qr'),
            ),
            if (checkin.hasPickupCode)
              ListTile(
                leading: const Icon(Icons.password),
                title: const Text('Digitar senha de 5 dígitos'),
                subtitle: Text('Termina em ${checkin.pickupCodeLast2 ?? '??'}'),
                onTap: () => Navigator.of(ctx).pop('code'),
              ),
            ListTile(
              leading: const Icon(Icons.warning_amber_outlined),
              title: const Text('Liberação manual'),
              subtitle: const Text('Registra quem retirou e o motivo'),
              onTap: () => Navigator.of(ctx).pop('manual'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case 'qr':
        final token = await Navigator.of(context).push<String>(
          MaterialPageRoute(
            builder: (_) => const KidsScanPage(title: 'QR do responsável'),
          ),
        );
        if (token == null || !mounted) return;
        await _doCheckOut(checkin, qrToken: token);
      case 'code':
        final code = await showDialog<String>(
          context: context,
          builder: (_) => _PickupCodeInputDialog(childName: checkin.childName),
        );
        if (code == null || !mounted) return;
        await _doCheckOut(checkin, pickupCode: code);
      case 'manual':
        final data = await showDialog<({String name, String reason})>(
          context: context,
          builder: (_) => _ManualReleaseDialog(childName: checkin.childName),
        );
        if (data == null || !mounted) return;
        await _doCheckOut(
          checkin,
          guardianName: data.name,
          reason: data.reason,
        );
    }
  }

  Future<void> _doCheckOut(
    KidsCheckin checkin, {
    String? qrToken,
    String? pickupCode,
    String? guardianName,
    String? reason,
  }) async {
    try {
      await _repo.checkOut(
        checkin.id,
        qrToken: qrToken,
        pickupCode: pickupCode,
        guardianName: guardianName,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${checkin.childName} foi retirada')),
      );
      _load();
    } on DioException catch (e) {
      if (!mounted) return;
      showKidsError(
        context,
        kidsErrorMessage(e, 'Não foi possível concluir a retirada'),
      );
    }
  }

  // ── Anotações e alertas ───────────────────────────────────────────────────

  Future<void> _addNote({KidsCheckin? checkin}) async {
    final data = await showModalBottomSheet<({String body, bool visible})>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _NoteSheet(childName: checkin?.childName),
    );
    if (data == null || !mounted) return;

    try {
      await _repo.createNote(
        sessionId: widget.sessionId,
        kind: checkin == null ? 'CLASS' : 'INDIVIDUAL',
        childId: checkin?.childId,
        checkinId: checkin?.id,
        body: data.body,
        visibleToGuardian: data.visible,
      );
      if (mounted) _load();
    } on DioException catch (e) {
      if (!mounted) return;
      showKidsError(
        context,
        kidsErrorMessage(e, 'Não foi possível salvar a anotação'),
      );
    }
  }

  Future<void> _sendAlert(KidsCheckin checkin) async {
    final data =
        await showModalBottomSheet<({KidsAlertLevel level, String message})>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _AlertSheet(childName: checkin.childName),
        );
    if (data == null || !mounted) return;

    try {
      final alert = await _repo.createAlert(
        checkinId: checkin.id,
        level: data.level,
        message: data.message,
      );
      if (!mounted) return;
      // Emergência sempre termina numa ligação: a tela já abre o discador.
      if (alert.level == KidsAlertLevel.emergency &&
          alert.guardianPhones.isNotEmpty) {
        await _promptCall(alert);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Alerta enviado (${alert.level.label})')),
        );
      }
      if (mounted) _load();
    } on DioException catch (e) {
      if (!mounted) return;
      showKidsError(
        context,
        kidsErrorMessage(e, 'Não foi possível enviar o alerta'),
      );
    }
  }

  Future<void> _promptCall(KidsAlert alert) async {
    final phone = alert.guardianPhones.first;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ligar para o responsável'),
        content: Text(
          'Emergência registrada. Ligue agora para $phone — a ligação fica '
          'registrada no alerta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Agora não'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.call),
            label: const Text('Ligar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await launchUrl(Uri.parse('tel:$phone'));
    await _repo.registerCall(alert.id);
  }

  // ── Fechamento ────────────────────────────────────────────────────────────

  Future<void> _closeSession() async {
    try {
      await _repo.closeSession(widget.sessionId);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sala fechada')));
      context.pop();
    } on DioException catch (e) {
      if (!mounted) return;
      // O backend devolve quem ficou dentro — mostrar a lista é mais útil que
      // repetir "ainda há crianças na sala".
      final details = kidsErrorDetails(e);
      final pending = (details?['pending'] as List? ?? [])
          .map((p) => (p as Map)['childName'] as String? ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      if (pending.isEmpty) {
        showKidsError(
          context,
          kidsErrorMessage(e, 'Não foi possível fechar a sala'),
        );
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Ainda há crianças na sala'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Faça o check-out antes de fechar:'),
              const SizedBox(height: AppSpacing.sm),
              for (final name in pending) Text('• $name'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;

    return Scaffold(
      appBar: AppBar(
        title: Text(session?.roomName ?? 'Sala'),
        actions: [
          if (session != null && session.isOpen)
            IconButton(
              tooltip: 'Fechar sala',
              icon: const Icon(Icons.lock_outline),
              onPressed: _closeSession,
            ),
        ],
      ),
      floatingActionButton: session == null || !session.isOpen
          ? null
          : FloatingActionButton.extended(
              onPressed: _showCheckInOptions,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text('Check-in'),
            ),
      body: _body(),
    );
  }

  Future<void> _showCheckInOptions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            ListTile(
              leading: const Icon(Icons.qr_code_scanner),
              title: const Text('Ler QR do app do responsável'),
              subtitle: const Text('Caminho rápido e sem senha'),
              onTap: () => Navigator.of(ctx).pop('qr'),
            ),
            ListTile(
              leading: const Icon(Icons.search),
              title: const Text('Buscar criança já cadastrada'),
              onTap: () => Navigator.of(ctx).pop('search'),
            ),
            ListTile(
              leading: const Icon(Icons.person_add_outlined),
              title: const Text('Cadastro rápido'),
              subtitle: const Text('Criança nova, gera senha de retirada'),
              onTap: () => Navigator.of(ctx).pop('quick'),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'qr':
        await _checkInByQr();
      case 'search':
        await _checkInBySearch();
      case 'quick':
        await _quickRegister();
    }
  }

  Widget _body() {
    if (_loading) return const Center(child: AppLoadingIndicator(size: 32));
    if (_error != null) return AppErrorState(message: _error!, onRetry: _load);
    final session = _session;
    if (session == null) return const SizedBox.shrink();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${session.serviceName} · ${formatDate(session.serviceDate)}',
                        style: AppTypography.titleSmall,
                      ),
                    ),
                    AppBadge(
                      label: session.isOpen ? 'Aberta' : 'Fechada',
                      variant: session.isOpen
                          ? AppBadgeVariant.success
                          : AppBadgeVariant.neutral,
                      size: AppBadgeSize.sm,
                    ),
                  ],
                ),
                if (session.lesson != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Lição: ${session.lesson}',
                    style: AppTypography.bodySmall,
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                KidsOccupancyBar(
                  current: session.presentCount,
                  capacity: session.capacity,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.base),

          AppSectionHeader(
            title: 'Na sala (${_present.length})',
            actionLabel: session.isOpen ? 'Anotação da aula' : null,
            onAction: () => _addNote(),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (_present.isEmpty)
            const AppEmptyState(
              title: 'Nenhuma criança na sala',
              subtitle: 'Use o botão de check-in para receber a primeira.',
              icon: Icons.child_care_outlined,
            )
          else
            for (final checkin in _present)
              KidsChildTile(
                checkin: checkin,
                onTap: () => _showChildActions(checkin),
                trailing: IconButton(
                  tooltip: 'Retirar',
                  icon: const Icon(Icons.logout),
                  onPressed: () => _checkOut(checkin),
                ),
              ),

          if (_gone.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.base),
            AppSectionHeader(title: 'Já retiradas (${_gone.length})'),
            const SizedBox(height: AppSpacing.sm),
            for (final checkin in _gone)
              KidsChildTile(
                checkin: checkin,
                onTap: () => _showChildActions(checkin),
              ),
          ],

          if (_notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.base),
            AppSectionHeader(title: 'Anotações (${_notes.length})'),
            const SizedBox(height: AppSpacing.sm),
            for (final note in _notes) _NoteCard(note: note),
          ],
          const SizedBox(height: AppSpacing.xl2),
        ],
      ),
    );
  }

  Future<void> _showChildActions(KidsCheckin checkin) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppSpacing.md),
            Text(checkin.childName, style: AppTypography.titleSmall),
            const SizedBox(height: AppSpacing.sm),
            if (!checkin.health.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base,
                ),
                child: KidsHealthBadges(health: checkin.health),
              ),
            const SizedBox(height: AppSpacing.sm),
            ListTile(
              leading: const Icon(Icons.notes_outlined),
              title: const Text('Anotação individual'),
              onTap: () => Navigator.of(ctx).pop('note'),
            ),
            if (checkin.isPresent) ...[
              ListTile(
                leading: const Icon(Icons.campaign_outlined),
                title: const Text('Avisar responsável'),
                subtitle: const Text('Aviso, urgente ou emergência'),
                onTap: () => Navigator.of(ctx).pop('alert'),
              ),
              if (checkin.hasPickupCode)
                ListTile(
                  leading: const Icon(Icons.key_outlined),
                  title: const Text('Gerar nova senha'),
                  subtitle: const Text('Invalida a senha anterior'),
                  onTap: () => Navigator.of(ctx).pop('code'),
                ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Retirar criança'),
                onTap: () => Navigator.of(ctx).pop('checkout'),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case 'note':
        await _addNote(checkin: checkin);
      case 'alert':
        await _sendAlert(checkin);
      case 'checkout':
        await _checkOut(checkin);
      case 'code':
        await _regenerateCode(checkin);
    }
  }

  Future<void> _regenerateCode(KidsCheckin checkin) async {
    try {
      final code = await _repo.regenerateCode(checkin.id);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Nova senha de ${checkin.childName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                code,
                style: AppTypography.kpiValue.copyWith(letterSpacing: 6),
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text('A senha anterior deixou de valer.'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Entendi'),
            ),
          ],
        ),
      );
      if (mounted) _load();
    } on DioException catch (e) {
      if (!mounted) return;
      showKidsError(
        context,
        kidsErrorMessage(e, 'Não foi possível gerar a senha'),
      );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Sheets e diálogos
// ═══════════════════════════════════════════════════════════════════════════

/// Escolha de quais filhos do responsável ficam na sala. Multi-filho é comum:
/// o QR traz todos, e o professor marca quem entra.
class _ChildPickerSheet extends StatefulWidget {
  const _ChildPickerSheet({required this.children});

  final List<KidsChild> children;

  @override
  State<_ChildPickerSheet> createState() => _ChildPickerSheetState();
}

class _ChildPickerSheetState extends State<_ChildPickerSheet> {
  late final Set<String> _selected = {
    for (final c in widget.children)
      if (!c.isInRoom) c.id,
  };

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.base),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quem fica na sala?', style: AppTypography.titleMedium),
            const SizedBox(height: AppSpacing.md),
            for (final child in widget.children)
              CheckboxListTile(
                value: _selected.contains(child.id),
                // Criança já dentro de outra sala não pode entrar de novo.
                onChanged: child.isInRoom
                    ? null
                    : (v) => setState(() {
                        if (v == true) {
                          _selected.add(child.id);
                        } else {
                          _selected.remove(child.id);
                        }
                      }),
                title: Text(child.name),
                subtitle: Text(
                  child.isInRoom
                      ? 'Já está em ${child.openCheckin?.badgeCode ?? 'outra sala'}'
                      : child.ageLabel,
                ),
              ),
            const SizedBox(height: AppSpacing.md),
            AppButton(
              label: 'Confirmar check-in',
              onPressed: _selected.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(_selected.toList()),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchChildSheet extends StatefulWidget {
  const _SearchChildSheet({required this.repo});

  final KidsRepository repo;

  @override
  State<_SearchChildSheet> createState() => _SearchChildSheetState();
}

class _SearchChildSheetState extends State<_SearchChildSheet> {
  final _ctrl = TextEditingController();
  List<KidsChild> _results = [];
  bool _searching = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() => _results = []);
      return;
    }
    setState(() => _searching = true);
    try {
      final results = await widget.repo.searchChildren(query);
      if (!mounted) return;
      setState(() {
        _results = results;
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
              Text('Buscar criança', style: AppTypography.titleMedium),
              const SizedBox(height: AppSpacing.md),
              AppTextField(
                controller: _ctrl,
                autofocus: true,
                hint: 'Nome da criança ou telefone do responsável',
                prefixIcon: Icons.search,
                onChanged: _search,
              ),
              const SizedBox(height: AppSpacing.md),
              if (_searching)
                const Center(child: AppLoadingIndicator())
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final child in _results)
                        ListTile(
                          leading: AppAvatar(initials: child.initials),
                          title: Text(child.name),
                          subtitle: Text(
                            [
                              child.ageLabel,
                              if (child.primaryGuardian != null)
                                child.primaryGuardian!.name,
                            ].join(' · '),
                          ),
                          onTap: () => Navigator.of(context).pop(child.id),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickupCodeInputDialog extends StatefulWidget {
  const _PickupCodeInputDialog({required this.childName});

  final String childName;

  @override
  State<_PickupCodeInputDialog> createState() => _PickupCodeInputDialogState();
}

class _PickupCodeInputDialogState extends State<_PickupCodeInputDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Senha de ${widget.childName}'),
      content: AppTextField(
        controller: _ctrl,
        autofocus: true,
        hint: '5 dígitos',
        keyboardType: TextInputType.number,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final code = _ctrl.text.trim();
            if (code.length != 5) return;
            Navigator.of(context).pop(code);
          },
          child: const Text('Confirmar'),
        ),
      ],
    );
  }
}

class _ManualReleaseDialog extends StatefulWidget {
  const _ManualReleaseDialog({required this.childName});

  final String childName;

  @override
  State<_ManualReleaseDialog> createState() => _ManualReleaseDialogState();
}

class _ManualReleaseDialogState extends State<_ManualReleaseDialog> {
  final _nameCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Liberação manual'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Fica registrado quem retirou ${widget.childName} e por quê.',
            style: AppTypography.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          AppTextField(controller: _nameCtrl, label: 'Quem retirou'),
          const SizedBox(height: AppSpacing.md),
          AppTextField(controller: _reasonCtrl, label: 'Motivo'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            final reason = _reasonCtrl.text.trim();
            if (name.isEmpty || reason.isEmpty) return;
            Navigator.of(context).pop((name: name, reason: reason));
          },
          child: const Text('Liberar'),
        ),
      ],
    );
  }
}

class _NoteSheet extends StatefulWidget {
  const _NoteSheet({this.childName});

  final String? childName;

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  final _ctrl = TextEditingController();
  bool _visible = true;

  @override
  void dispose() {
    _ctrl.dispose();
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
                widget.childName == null
                    ? 'Anotação da aula'
                    : 'Anotação sobre ${widget.childName}',
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              AppTextField(controller: _ctrl, maxLines: 4, autofocus: true),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _visible,
                onChanged: (v) => setState(() => _visible = v),
                title: const Text('Visível para o responsável'),
                subtitle: const Text(
                  'Desligue para deixar como registro interno',
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppButton(
                label: 'Salvar',
                onPressed: () {
                  final body = _ctrl.text.trim();
                  if (body.isEmpty) return;
                  Navigator.of(context).pop((body: body, visible: _visible));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Escolha do nível do alerta. Emergência exige toque longo — nível 3 dispara
/// ligação e notificação crítica, e não pode sair por engano.
class _AlertSheet extends StatefulWidget {
  const _AlertSheet({required this.childName});

  final String childName;

  @override
  State<_AlertSheet> createState() => _AlertSheetState();
}

class _AlertSheetState extends State<_AlertSheet> {
  final _ctrl = TextEditingController();
  KidsAlertLevel _level = KidsAlertLevel.info;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                'Avisar responsável de ${widget.childName}',
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              // Cada nível diz por onde o aviso sai — o professor escolhe pelo
              // efeito, não pelo nome.
              for (final level in KidsAlertLevel.values)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  onTap: () => setState(() => _level = level),
                  leading: Icon(
                    _level == level
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: alertLevelColor(level, isDark: isDark),
                  ),
                  title: Text(level.label),
                  subtitle: Text(switch (level) {
                    KidsAlertLevel.info =>
                      'Notificação no app; WhatsApp se não tiver app',
                    KidsAlertLevel.urgent =>
                      'Notificação e WhatsApp em paralelo',
                    KidsAlertLevel.emergency =>
                      'Notificação crítica, WhatsApp e ligação imediata',
                  }),
                ),
              const SizedBox(height: AppSpacing.sm),
              AppTextField(
                controller: _ctrl,
                maxLines: 3,
                label: 'Mensagem',
                hint: 'Descreva o que está acontecendo',
                // Dado clínico não vai para push/WhatsApp — só o pedido de vir
                // à sala. O detalhe fica na ficha, atrás de autenticação.
                helperText:
                    'Não inclua dados de saúde: a mensagem sai por WhatsApp.',
              ),
              const SizedBox(height: AppSpacing.md),
              AppButton(
                label: _level == KidsAlertLevel.emergency
                    ? 'Enviar emergência'
                    : 'Enviar aviso',
                variant: _level == KidsAlertLevel.emergency
                    ? AppButtonVariant.danger
                    : AppButtonVariant.primary,
                onPressed: () {
                  final message = _ctrl.text.trim();
                  if (message.isEmpty) return;
                  Navigator.of(context).pop((level: _level, message: message));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.note});

  final KidsNote note;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;

    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppBadge(
                label: note.isClassNote ? 'Aula' : note.childName ?? 'Criança',
                variant: note.isClassNote
                    ? AppBadgeVariant.info
                    : AppBadgeVariant.neutral,
                size: AppBadgeSize.sm,
              ),
              const Spacer(),
              if (!note.visibleToGuardian)
                Icon(
                  Icons.visibility_off_outlined,
                  size: 14,
                  color: mutedColor,
                ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                formatTime(note.createdAt),
                style: AppTypography.bodySmall.copyWith(color: mutedColor),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(note.body, style: AppTypography.bodyMedium),
          const SizedBox(height: 2),
          Text(
            note.authorName,
            style: AppTypography.bodySmall.copyWith(color: mutedColor),
          ),
        ],
      ),
    );
  }
}
