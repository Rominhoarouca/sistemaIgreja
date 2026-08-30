import 'package:flutter/material.dart';

import '../../design_system/design_system.dart';

/// Badge com o tipo da célula (jovens, casais, kids…).
///
/// Some quando a célula não tem tipo — badge vazio ocuparia espaço sem
/// informar nada.
class CellTypeBadge extends StatelessWidget {
  const CellTypeBadge({super.key, required this.typeName, this.size = AppBadgeSize.sm});

  final String? typeName;
  final AppBadgeSize size;

  /// `true` quando há tipo para mostrar — evita `SizedBox.shrink()` deixando
  /// um espaçador solto no meio de um Row/Wrap do chamador.
  static bool has(String? typeName) =>
      typeName != null && typeName.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!has(typeName)) return const SizedBox.shrink();
    return AppBadge(
      label: typeName!.trim(),
      variant: AppBadgeVariant.info,
      icon: Icons.category_outlined,
      size: size,
    );
  }
}
