import 'package:flutter/material.dart';
import '../../../../design_system/design_system.dart';

/// Helper centralizado para snackbars do dashboard.
/// SRP: única responsabilidade — exibir mensagens de feedback.
void showDashboardSnackBar(
  BuildContext context,
  String message, {
  Color backgroundColor = AppColors.error,
}) {
  final rootContext = Navigator.of(context, rootNavigator: true).context;
  final messenger = ScaffoldMessenger.maybeOf(rootContext);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), backgroundColor: backgroundColor),
    );
}
