import 'package:flutter/material.dart';
import 'admin_sidebar.dart';

/// Breakpoint do shell desktop (sidebar fixa).
const double kAdminDesktopBreakpoint = 1024;

/// Shell do admin: no desktop envolve o conteúdo com a sidebar navy fixa;
/// no mobile devolve o conteúdo puro (as páginas usam bottom-nav/appbar).
class AdminScaffold extends StatelessWidget {
  const AdminScaffold({super.key, required this.child});

  final Widget child;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= kAdminDesktopBreakpoint;

  @override
  Widget build(BuildContext context) {
    if (!isDesktop(context)) return child;
    return Scaffold(
      body: Row(
        children: [
          const AdminSidebar(),
          Expanded(child: child),
        ],
      ),
    );
  }
}
