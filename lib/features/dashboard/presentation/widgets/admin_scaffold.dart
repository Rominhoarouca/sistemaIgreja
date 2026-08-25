import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import 'admin_sidebar.dart';

/// Breakpoint do shell desktop (sidebar fixa).
const double kAdminDesktopBreakpoint = 1024;

/// Shell do admin: no desktop envolve o conteúdo com a sidebar navy fixa;
/// no mobile devolve o conteúdo puro (as páginas usam bottom-nav/appbar).
///
/// Algumas rotas do shell (ex.: /notifications) são compartilhadas com outros
/// papéis — a sidebar (menu só de admin) só aparece se quem está logado
/// realmente for ADMIN/SUPERADMIN, senão o conteúdo é devolvido puro mesmo
/// no desktop.
class AdminScaffold extends StatelessWidget {
  const AdminScaffold({super.key, required this.child});

  final Widget child;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= kAdminDesktopBreakpoint;

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.select<AuthBloc, bool>((bloc) {
      final state = bloc.state;
      return state is AuthAuthenticated &&
          (state.user.isAdmin || state.user.isSuperAdmin);
    });
    if (!isDesktop(context) || !isAdmin) return child;
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
