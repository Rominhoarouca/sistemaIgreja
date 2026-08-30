import 'package:equatable/equatable.dart';

/// Domain entity — User (admin / leader)
class UserEntity extends Equatable {
  const UserEntity({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    this.roles = const {},
    this.createdAt,
    this.description,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  /// Papel principal — define a home do usuário ao entrar.
  final UserRole role;

  /// Papéis adicionais. Uma mesma pessoa pode ser líder, supervisor, admin e
  /// coordenador ao mesmo tempo; as permissões são a união de todos.
  final Set<UserRole> roles;
  final bool isActive;
  final DateTime? createdAt;
  final String? description;

  /// União de [role] e [roles], na ordem de precedência dos papéis.
  Set<UserRole> get allRoles => {role, ...roles};

  bool hasRole(UserRole r) => allRoles.contains(r);

  bool get isSuperAdmin => hasRole(UserRole.superAdmin);
  bool get isAdmin => hasRole(UserRole.admin);
  bool get isLeader => hasRole(UserRole.leader);
  bool get isSupervisor => hasRole(UserRole.supervisor);
  bool get isCoordinator => hasRole(UserRole.coordinator);
  bool get isKidsTeacher => hasRole(UserRole.kids);
  bool get isGuardian => hasRole(UserRole.responsavel);

  /// Mais de um perfil — habilita o seletor de perfil no menu.
  bool get hasMultipleRoles => allRoles.length > 1;

  @override
  List<Object?> get props => [id, email, role, roles];
}

/// Ordem = precedência (mais privilegiado primeiro).
enum UserRole {
  superAdmin,
  admin,
  leader,
  supervisor,
  coordinator,

  /// Professor da salinha (módulo Kids).
  kids,

  /// Pai/responsável — vê apenas os próprios filhos (módulo Kids).
  responsavel;

  static UserRole fromString(String value) => switch (value.toUpperCase()) {
    'SUPERADMIN' => superAdmin,
    'ADMIN' => admin,
    'SUPERVISOR' => supervisor,
    'COORDENADOR' => coordinator,
    'KIDS' => kids,
    'RESPONSAVEL' => responsavel,
    _ => leader,
  };

  /// Rótulo exibido ao usuário.
  String get label => switch (this) {
    UserRole.superAdmin => 'Super administrador',
    UserRole.admin => 'Administrador',
    UserRole.leader => 'Líder',
    UserRole.supervisor => 'Supervisor',
    UserRole.coordinator => 'Coordenador',
    UserRole.kids => 'Professor do Kids',
    UserRole.responsavel => 'Responsável',
  };

  String get value => switch (this) {
    UserRole.superAdmin => 'SUPERADMIN',
    UserRole.admin => 'ADMIN',
    UserRole.leader => 'LIDER',
    UserRole.supervisor => 'SUPERVISOR',
    UserRole.coordinator => 'COORDENADOR',
    UserRole.kids => 'KIDS',
    UserRole.responsavel => 'RESPONSAVEL',
  };
}
