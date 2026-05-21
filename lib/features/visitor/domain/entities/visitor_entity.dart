import 'package:equatable/equatable.dart';

/// Domain entity — Visitor
class VisitorEntity extends Equatable {
  const VisitorEntity({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    required this.neighborhood,
    required this.city,
    required this.status,
    required this.registeredAt,
    this.email,
    this.visitDate,
    this.originChurch,
    this.latitude,
    this.longitude,
    this.assignedCellId,
  });

  final String id;
  final String name;
  final String phone;
  final String address;
  final String neighborhood;
  final String city;
  final VisitorStatus status;
  final DateTime registeredAt;

  // Optional
  final String? email;
  final DateTime? visitDate;
  final String? originChurch;
  final double? latitude;
  final double? longitude;
  final String? assignedCellId;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  List<Object?> get props => [id, phone, email];
}

enum VisitorStatus {
  newVisitor,
  following,
  integrated,
  inactive;

  static VisitorStatus fromString(String value) =>
      switch (value.toLowerCase()) {
        'em_acompanhamento' || 'following' => following,
        'integrado' || 'integrated' => integrated,
        'inativo' || 'inactive' || 'nao_retornou' => inactive,
        _ => newVisitor,
      };

  String get value => switch (this) {
    VisitorStatus.newVisitor => 'novo',
    VisitorStatus.following => 'em_acompanhamento',
    VisitorStatus.integrated => 'integrado',
    VisitorStatus.inactive => 'inativo',
  };

  String get label => switch (this) {
    VisitorStatus.newVisitor => 'Novo visitante',
    VisitorStatus.following => 'Em acompanhamento',
    VisitorStatus.integrated => 'Integrado',
    VisitorStatus.inactive => 'Não retornou',
  };
}
