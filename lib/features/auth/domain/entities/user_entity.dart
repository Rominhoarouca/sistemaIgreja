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
    this.createdAt,
    this.description,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;
  final bool isActive;
  final DateTime? createdAt;
  final String? description;

  bool get isAdmin => role == UserRole.admin;
  bool get isLeader => role == UserRole.leader;
  bool get isSupervisor => role == UserRole.supervisor;
  bool get isCoordinator => role == UserRole.coordinator;

  @override
  List<Object?> get props => [id, email, role];
}

enum UserRole {
  admin,
  leader,
  supervisor,
  coordinator;

  static UserRole fromString(String value) => switch (value.toUpperCase()) {
    'ADMIN' => admin,
    'SUPERVISOR' => supervisor,
    'COORDENADOR' => coordinator,
    _ => leader,
  };

  String get value => switch (this) {
    UserRole.admin => 'ADMIN',
    UserRole.leader => 'LIDER',
    UserRole.supervisor => 'SUPERVISOR',
    UserRole.coordinator => 'COORDENADOR',
  };
}
