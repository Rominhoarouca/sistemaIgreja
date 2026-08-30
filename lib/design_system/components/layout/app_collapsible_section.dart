import 'package:flutter/material.dart';

import '../../colors/app_colors.dart';
import '../../spacing/app_spacing.dart';
import '../../typography/app_typography.dart';

/// Seção recolhível com o mesmo cabeçalho do [AppSectionHeader].
///
/// As telas de célula e a home empilham várias listas longas; com tudo aberto
/// o usuário rola muito para chegar na seção seguinte. O estado fica no widget
/// porque é preferência de leitura do momento, não dado de domínio.
class AppCollapsibleSection extends StatefulWidget {
  const AppCollapsibleSection({
    super.key,
    required this.title,
    required this.child,
    this.initiallyExpanded = true,
    this.trailing,
  });

  final String title;
  final Widget child;

  /// Começa aberta. Use `false` em seções secundárias.
  final bool initiallyExpanded;

  /// Widget opcional antes da seta (contador, botão de ação).
  final Widget? trailing;

  @override
  State<AppCollapsibleSection> createState() => _AppCollapsibleSectionState();
}

class _AppCollapsibleSectionState extends State<AppCollapsibleSection> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: AppTypography.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.trailing != null) ...[
                  widget.trailing!,
                  const SizedBox(width: AppSpacing.sm),
                ],
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: isDark ? AppColors.text3Dark : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        // O conteúdo sai da árvore quando fechado: manter listas longas
        // montadas só para escondê-las custa layout a cada frame.
        if (_expanded) ...[
          const SizedBox(height: AppSpacing.sm),
          widget.child,
        ],
      ],
    );
  }
}
