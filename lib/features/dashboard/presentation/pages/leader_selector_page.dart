import 'package:flutter/material.dart';
import '../../../../design_system/design_system.dart';
import '../../domain/models/leader_option.dart';

/// Sentinela devolvida quando o usuário escolhe "sem líder" — distingue
/// "cancelou a tela" (null) de "quer a célula sem líder".
const LeaderOption noLeaderOption = LeaderOption(id: '', name: '', email: '');

/// SRP: responsável apenas por exibir a seleção de líderes.
class LeaderSelectorPage extends StatefulWidget {
  const LeaderSelectorPage({
    super.key,
    required this.leaders,
    required this.initialId,
  });

  final List<LeaderOption> leaders;
  final String? initialId;

  @override
  State<LeaderSelectorPage> createState() => _LeaderSelectorPageState();
}

class _LeaderSelectorPageState extends State<LeaderSelectorPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.leaders.where((l) {
      final q = _query.toLowerCase();
      return l.name.toLowerCase().contains(q) ||
          l.email.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Selecionar líder')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePaddingH),
        child: Column(
          children: [
            AppSearchField(
              hint: 'Pesquisar líder...',
              controller: _searchCtrl,
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: AppSpacing.base),
            // "Sem líder" é a primeira opção: a célula pode ser cadastrada
            // antes de existir líder para ela (`null` limpa a seleção).
            AppCard(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              onTap: () => Navigator.of(context).pop(noLeaderOption),
              child: Row(
                children: [
                  const Icon(
                    Icons.person_off_outlined,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      'Sem líder por enquanto',
                      style: AppTypography.titleSmall,
                    ),
                  ),
                  if (widget.initialId == null)
                    const Icon(Icons.check_circle, color: AppColors.success),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final leader = filtered[index];
                  final isSelected = leader.id == widget.initialId;
                  return AppCard(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    onTap: () => Navigator.of(context).pop(leader),
                    child: Row(
                      children: [
                        AppAvatar(
                          initials: leader.name
                              .split(' ')
                              .map((e) => e[0])
                              .take(2)
                              .join(),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                leader.name,
                                style: AppTypography.titleSmall,
                              ),
                              const SizedBox(height: AppSpacing.xs2),
                              Text(
                                leader.email,
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: AppColors.success,
                          ),
                      ],
                    ),
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
