import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../../design_system/design_system.dart';
import '../../../../injection/injection.dart';
import '../../data/kids_models.dart';
import '../../data/kids_repository.dart';
import '../widgets/kids_widgets.dart';
import 'guardian_child_form_page.dart';

/// Ficha do filho, para o responsável: dados, saúde e quem mais é
/// responsável por ele. Editar e remover partem daqui.
class GuardianChildDetailPage extends StatefulWidget {
  const GuardianChildDetailPage({super.key, required this.childId});

  final String childId;

  @override
  State<GuardianChildDetailPage> createState() =>
      _GuardianChildDetailPageState();
}

class _GuardianChildDetailPageState extends State<GuardianChildDetailPage> {
  late final KidsRepository _repo;
  bool _loading = true;
  bool _deleting = false;
  String? _error;
  KidsChild? _child;

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
      final child = await _repo.getChild(widget.childId);
      if (!mounted) return;
      setState(() {
        _child = child;
        _loading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = kidsErrorMessage(e, 'Erro ao carregar a ficha');
        _loading = false;
      });
    }
  }

  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<KidsChild>(
      MaterialPageRoute(
        builder: (_) => GuardianChildFormPage(existing: _child),
      ),
    );
    if (updated != null && mounted) setState(() => _child = updated);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover cadastro'),
        content: Text(
          'Remover ${_child?.name ?? 'esta criança'} da salinha? '
          'A equipe do ministério infantil não vai mais encontrá-la nas buscas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      await _repo.deleteChild(widget.childId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      // Qualquer exceção, não só DioException: senão o botão fica travado
      // em "carregando" sem explicação.
      if (!mounted) return;
      setState(() => _deleting = false);
      showKidsError(context, kidsErrorMessage(e, 'Não foi possível remover'));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_child?.name ?? 'Filho'),
        actions: [
          if (_child != null)
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _edit,
            ),
        ],
      ),
      body: _body(),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: AppLoadingIndicator(size: 32));
    if (_error != null) return AppErrorState(message: _error!, onRetry: _load);
    final child = _child;
    if (child == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor = isDark ? AppColors.text3Dark : AppColors.textSecondary;

    return AppContentWidth(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
          children: [
            AppCard(
              child: Row(
                children: [
                  AppAvatar(initials: child.initials),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(child.name, style: AppTypography.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          child.ageLabel,
                          style: AppTypography.bodySmall.copyWith(
                            color: mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppBadge(
                    label: child.isInRoom ? 'Na sala' : 'Em casa',
                    variant: child.isInRoom
                        ? AppBadgeVariant.success
                        : AppBadgeVariant.neutral,
                    size: AppBadgeSize.sm,
                  ),
                ],
              ),
            ),

            if (!child.health.isEmpty) ...[
              const SizedBox(height: AppSpacing.base),
              AppSectionHeader(title: 'Cuidados especiais'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(child: KidsHealthBadges(health: child.health)),
            ],

            if ((child.authorizedPickup ?? '').isNotEmpty) ...[
              const SizedBox(height: AppSpacing.base),
              AppSectionHeader(title: 'Quem mais pode retirar'),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Text(
                  child.authorizedPickup!,
                  style: AppTypography.bodyMedium,
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.base),
            AppSectionHeader(title: 'Responsáveis'),
            const SizedBox(height: AppSpacing.sm),
            for (final guardian in child.guardians)
              AppCard(
                margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(guardian.name, style: AppTypography.titleSmall),
                          Text(
                            '${guardian.relationLabel} · ${guardian.phone}',
                            style: AppTypography.bodySmall.copyWith(
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (guardian.isPrimary)
                      const AppBadge(
                        label: 'Principal',
                        variant: AppBadgeVariant.primary,
                        size: AppBadgeSize.sm,
                      ),
                    if (!guardian.hasApp) ...[
                      const SizedBox(width: AppSpacing.xs),
                      const AppBadge(
                        label: 'Sem app',
                        variant: AppBadgeVariant.neutral,
                        size: AppBadgeSize.sm,
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Remover cadastro',
              variant: AppButtonVariant.danger,
              isLoading: _deleting,
              onPressed: _deleting ? null : _delete,
            ),
            const SizedBox(height: AppSpacing.xl2),
          ],
        ),
      ),
    );
  }
}
