import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/constants/app_constants.dart';
import '../features/auth/domain/entities/user_entity.dart';
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
import '../features/admin/presentation/pages/admin_leaders_page.dart';
import '../features/admin/presentation/pages/admin_supervisors_page.dart';
import '../features/admin/presentation/pages/admin_coordenacoes_page.dart';
import '../features/admin/presentation/pages/admin_location_page.dart';
import '../features/visitor/presentation/pages/visitor_self_register_page.dart';
import '../features/supervisor/presentation/pages/supervisor_home_page.dart';
import '../features/coordinator/presentation/pages/coordinator_home_page.dart';
import '../features/admin/presentation/pages/admin_cell_types_page.dart';
import '../features/admin/presentation/pages/admin_qrcode_page.dart';
import '../features/leader/presentation/pages/leader_qrcode_page.dart';
import '../features/whatsapp/presentation/pages/admin_whatsapp_page.dart';
import '../features/admin/presentation/pages/admin_users_register_page.dart';
import '../features/dashboard/presentation/widgets/admin_scaffold.dart';
import '../features/saas/presentation/pages/church_admin_page.dart';
import '../features/saas/presentation/pages/church_signup_page.dart';
import '../features/saas/presentation/pages/super_admin_page.dart';
import '../features/saas/presentation/pages/plan_management_page.dart';

/// Public routes that can be accessed without authentication.
const _publicRoutes = {
  AppRoutes.login,
  AppRoutes.register,
  '/forgot-password',
  AppRoutes.visitorSelfRegister,
  AppRoutes.signup,
};

/// Routes that authenticated users are still allowed to visit freely
/// (not redirected to their home dashboard).
const _alwaysAllowedRoutes = {AppRoutes.visitorSelfRegister};

/// Home route for the user's role — used both to land after login and to
/// bounce a user away from a section that isn't theirs.
String _homeForRole(UserEntity user) {
  if (user.isSuperAdmin) return AppRoutes.superAdmin;
  if (user.isAdmin) return AppRoutes.adminDashboard;
  if (user.isSupervisor) return AppRoutes.supervisorHome;
  if (user.isCoordinator) return AppRoutes.coordinatorHome;
  return AppRoutes.leaderHome;
}

/// Whether [user] is allowed on [location]. Each role-owned section
/// (super-admin panel, admin shell, supervisor/coordinator/leader home) is
/// off-limits to every other role — only the owning role passes.
bool _isAllowedForRole(UserEntity user, String location) {
  if (location.startsWith(AppRoutes.superAdmin)) return user.isSuperAdmin;
  if (location.startsWith(AppRoutes.adminDashboard)) return user.isAdmin;
  if (location.startsWith(AppRoutes.supervisorHome)) return user.isSupervisor;
  if (location.startsWith(AppRoutes.coordinatorHome)) return user.isCoordinator;
  if (location.startsWith(AppRoutes.leaderHome)) return user.isLeader;
  return true; // shared routes (profile, notifications, visitor flows, etc.)
}

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

      if (authState is AuthAuthenticated) {
        // Some public routes (e.g. visitor self-register) must remain
        // accessible even while the user is logged in.
        if (_alwaysAllowedRoutes.any((r) => location.startsWith(r))) {
          return null;
        }
        if (isPublic) return _homeForRole(authState.user);

        // Authenticated but on a route owned by a different role (e.g. a
        // SUPERADMIN typing "/admin" in the address bar) — bounce home.
        if (!_isAllowedForRole(authState.user, location)) {
          return _homeForRole(authState.user);
        }
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

      // ── SaaS: cadastro público de igreja ──────────────────────────────
      GoRoute(
        path: AppRoutes.signup,
        name: 'signup',
        pageBuilder: (context, state) =>
            const MaterialPage(child: ChurchSignupPage()),
      ),

      // ── SaaS: painel super-admin (dono do SaaS) ───────────────────────
      GoRoute(
        path: AppRoutes.superAdmin,
        name: 'super-admin',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: SuperAdminPage()),
      ),
      GoRoute(
        path: AppRoutes.superAdminPlans,
        name: 'super-admin-plans',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: PlanManagementPage()),
      ),

      // ── Supervisor ────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.supervisorHome,
        name: 'supervisor-home',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: SupervisorHomePage()),
      ),

      // ── Coordenador ───────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.coordinatorHome,
        name: 'coordinator-home',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: CoordinatorHomePage()),
      ),

      // ── Leader ────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.leaderHome,
        name: 'leader-home',
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: LeaderHomePage()),
      ),

      // ── Admin (shell com sidebar no desktop) ──────────────────────────
      ShellRoute(
        builder: (context, state, child) => AdminScaffold(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.adminDashboard,
            name: 'admin-dashboard',
            pageBuilder: (context, state) {
              final tab =
                  int.tryParse(state.uri.queryParameters['tab'] ?? '') ?? 0;
              return NoTransitionPage(
                key: ValueKey('admin-dashboard-$tab'),
                child: AdminDashboardPage(initialTab: tab),
              );
            },
          ),

          // ── Admin Materials ───────────────────────────────────────────
          GoRoute(
            path: '/admin/materials',
            name: 'admin-materials',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminMaterialsPage()),
          ),

          // ── Admin Leaders ─────────────────────────────────────────────
          GoRoute(
            path: AppRoutes.adminLeaders,
            name: 'admin-leaders',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminLeadersPage()),
          ),

          // ── Admin Supervisors ─────────────────────────────────────────
          GoRoute(
            path: AppRoutes.adminSupervisors,
            name: 'admin-supervisors',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminSupervisorsPage()),
          ),

          // ── Admin Coordenações ────────────────────────────────────────
          GoRoute(
            path: AppRoutes.adminCoordenacoes,
            name: 'admin-coordenacoes',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminCoordenacoes()),
          ),

          // ── Admin Location (Cidades + Bairros) ────────────────────────
          GoRoute(
            path: AppRoutes.adminLocation,
            name: 'admin-location',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminLocationPage()),
          ),

          // ── Admin QR Code de cadastro ─────────────────────────────────
          GoRoute(
            path: AppRoutes.adminQrCode,
            name: 'admin-qrcode',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminQrCodePage()),
          ),

          // ── Admin Cell Types ──────────────────────────────────────────
          GoRoute(
            path: AppRoutes.adminCellTypes,
            name: 'admin-cell-types',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminCellTypesPage()),
          ),

          // ── Admin WhatsApp ────────────────────────────────────────────
          GoRoute(
            path: AppRoutes.adminWhatsapp,
            name: 'admin-whatsapp',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminWhatsappPage()),
          ),

          // ── Admin Users Register ──────────────────────────────────────
          GoRoute(
            path: AppRoutes.adminUsersRegister,
            name: 'admin-users-register',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: AdminUsersRegisterPage()),
          ),

          // ── SaaS: configurações da igreja ─────────────────────────────
          GoRoute(
            path: AppRoutes.adminChurch,
            name: 'admin-church',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ChurchAdminPage()),
          ),
        ],
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

      // ── Líder: QR Code de cadastro da célula ──────────────────────────
      GoRoute(
        path: AppRoutes.leaderQrCode,
        name: 'leader-qrcode',
        pageBuilder: (context, state) =>
            const MaterialPage(child: LeaderQrCodePage()),
      ),

      // ── Visitor flow ──────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.visitorRegister,
        name: 'visitor-register',
        pageBuilder: (context, state) =>
            const MaterialPage(child: VisitorRegisterPage()),
      ),
      GoRoute(
        path: AppRoutes.visitorSelfRegister,
        name: 'visitor-self-register',
        pageBuilder: (context, state) {
          // A igreja (e opcionalmente a célula) vem do QR Code / link.
          final q = state.uri.queryParameters;
          return MaterialPage(
            child: VisitorSelfRegisterPage(
              churchSlug: q['igreja'],
              presetCellId: q['celula'],
            ),
          );
        },
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
