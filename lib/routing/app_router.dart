import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_constants.dart';
import '../features/auth/presentation/bloc/auth_bloc.dart';
import '../features/auth/presentation/pages/login_page.dart';
import '../features/auth/presentation/pages/register_page.dart';
import '../features/auth/presentation/pages/forgot_password_page.dart';
import '../features/visitor/presentation/pages/visitor_register_page.dart';
import '../features/cell/presentation/pages/nearby_cells_page.dart';
import '../features/leader/presentation/pages/leader_home_page.dart';
import '../features/auth/presentation/pages/profile_page.dart';
import '../features/auth/presentation/pages/change_password_page.dart';
import '../features/notifications/presentation/pages/notifications_page.dart';
import '../features/about/presentation/pages/about_page.dart';
import '../features/dashboard/presentation/pages/admin_dashboard_page.dart';
import '../features/materials/presentation/pages/admin_materials_page.dart';

/// Public routes that can be accessed without authentication.
const _publicRoutes = {AppRoutes.login, AppRoutes.register, '/forgot-password'};

/// Creates a [GoRouter] that reacts to [AuthBloc] state changes.
GoRouter createRouter(AuthBloc authBloc) {
  final notifier = _AuthRouterNotifier(authBloc);

  return GoRouter(
    initialLocation: AppRoutes.login,
    debugLogDiagnostics: false,
    refreshListenable: notifier,

    redirect: (BuildContext context, GoRouterState state) {
      final authState = authBloc.state;
      final location = state.matchedLocation;
      final isPublic = _publicRoutes.any((r) => location.startsWith(r));

      // Still checking stored session — keep current location
      if (authState is AuthInitial || authState is AuthLoading) {
        return isPublic ? null : AppRoutes.login;
      }

      final isAuthenticated = authState is AuthAuthenticated;

      if (!isAuthenticated && !isPublic) return AppRoutes.login;

      if (authState is AuthAuthenticated && isPublic) {
        return authState.user.isAdmin
            ? AppRoutes.adminDashboard
            : AppRoutes.leaderHome;
      }

      return null;
    },

    routes: [
      // ── Auth ──────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LoginPage()),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        pageBuilder: (context, state) =>
            const MaterialPage(child: RegisterPage()),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        pageBuilder: (context, state) =>
            const MaterialPage(child: ForgotPasswordPage()),
      ),

      // ── Leader ────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.leaderHome,
        name: 'leader-home',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LeaderHomePage()),
      ),

      // ── Admin ─────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.adminDashboard,
        name: 'admin-dashboard',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: AdminDashboardPage()),
      ),

      // ── Profile ───────────────────────────────────────────────────────
      GoRoute(
        path: '/profile',
        name: 'profile',
        pageBuilder: (context, state) =>
            const MaterialPage(child: ProfilePage()),
      ),

      // ── Change password ───────────────────────────────────────────────
      GoRoute(
        path: '/change-password',
        name: 'change-password',
        pageBuilder: (context, state) =>
            const MaterialPage(child: ChangePasswordPage()),
      ),

      // ── Notifications ─────────────────────────────────────────────────
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        pageBuilder: (context, state) =>
            const MaterialPage(child: NotificationsPage()),
      ),

      // ── About ─────────────────────────────────────────────────────────
      GoRoute(
        path: '/about',
        name: 'about',
        pageBuilder: (context, state) => const MaterialPage(child: AboutPage()),
      ),

      // ── Admin Materials ───────────────────────────────────────────────
      GoRoute(
        path: '/admin/materials',
        name: 'admin-materials',
        pageBuilder: (context, state) =>
            const MaterialPage(child: AdminMaterialsPage()),
      ),

      // ── Visitor flow ──────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.visitorRegister,
        name: 'visitor-register',
        pageBuilder: (context, state) =>
            const MaterialPage(child: VisitorRegisterPage()),
      ),
      GoRoute(
        path: AppRoutes.nearbyCells,
        name: 'nearby-cells',
        pageBuilder: (context, state) {
          final name = state.uri.queryParameters['name'];
          return MaterialPage(child: NearbyCellsPage(visitorName: name));
        },
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text('Página não encontrada: ${state.uri}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.go(AppRoutes.login),
              child: const Text('Ir para login'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// [ChangeNotifier] that fires whenever the [AuthBloc] emits a new state,
/// causing [GoRouter] to re-evaluate its redirect logic.
class _AuthRouterNotifier extends ChangeNotifier {
  _AuthRouterNotifier(AuthBloc authBloc) {
    _subscription = authBloc.stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
