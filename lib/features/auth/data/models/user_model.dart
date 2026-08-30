import 'dart:convert';
import '../../domain/entities/user_entity.dart';

/// JSON-serializable model for the User domain entity.
class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.name,
    required super.email,
    required super.role,
    super.roles,
    super.phone = '',
    super.isActive = true,
    super.createdAt,
    super.description,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String? ?? '',
      role: UserRole.fromString(json['role'] as String? ?? 'LIDER'),
      // `roles` só existe a partir do multi-papel; sessão antiga cai no papel
      // principal apenas.
      roles: ((json['roles'] as List?) ?? const [])
          .map((r) => UserRole.fromString(r as String))
          .toSet(),
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String)
          : null,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'phone': phone,
    'role': role.value,
    'roles': [for (final r in allRoles) r.value],
    'isActive': isActive,
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (description != null) 'description': description,
  };

  String toJsonString() => jsonEncode(toJson());

  factory UserModel.fromJsonString(String jsonStr) =>
      UserModel.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
}
