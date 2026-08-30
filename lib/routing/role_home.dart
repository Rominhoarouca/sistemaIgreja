import '../core/constants/app_constants.dart';
import '../features/auth/domain/entities/user_entity.dart';

/// Rota inicial de cada perfil. Um usuário com vários papéis pode alternar
/// entre essas áreas pelo seletor de perfil.
String homeRouteForRole(UserRole role) => switch (role) {
  UserRole.superAdmin => AppRoutes.superAdmin,
  UserRole.admin => AppRoutes.adminDashboard,
  UserRole.supervisor => AppRoutes.supervisorHome,
  UserRole.coordinator => AppRoutes.coordinatorHome,
  UserRole.kids => AppRoutes.kidsHome,
  UserRole.responsavel => AppRoutes.guardianHome,
  UserRole.leader => AppRoutes.leaderHome,
};

/// Papéis do usuário na ordem de precedência declarada em [UserRole].
List<UserRole> orderedRoles(UserEntity user) =>
    UserRole.values.where(user.allRoles.contains).toList();
