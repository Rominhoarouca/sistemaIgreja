import '../../domain/entities/visitor_entity.dart';

/// Data model — Visitor (JSON serializable)
class VisitorModel extends VisitorEntity {
  const VisitorModel({
    required super.id,
    required super.name,
    required super.phone,
    required super.address,
    required super.neighborhood,
    required super.city,
    required super.status,
    required super.registeredAt,
    super.email,
    super.visitDate,
    super.originChurch,
    super.latitude,
    super.longitude,
    super.assignedCellId,
  });

  factory VisitorModel.fromJson(Map<String, dynamic> json) => VisitorModel(
    id: json['id'] as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
    email: json['email'] as String?,
    address: json['address'] as String? ?? '',
    neighborhood: json['neighborhood'] as String? ?? '',
    city: json['city'] as String? ?? '',
    latitude: null,
    longitude: null,
    registeredAt: DateTime.parse(json['createdAt'] as String),
    status: VisitorStatus.fromString(json['status'] as String? ?? 'novo'),
    visitDate: null,
    originChurch: json['originChurch'] as String?,
    assignedCellId: json['cellId'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'phone': phone,
    'email': email,
    'address': address,
    'neighborhood': neighborhood,
    'city': city,
    'createdAt': registeredAt.toIso8601String(),
    'status': status.value,
    'originChurch': originChurch,
    'cellId': assignedCellId,
  };

  factory VisitorModel.fromEntity(VisitorEntity entity) => VisitorModel(
    id: entity.id,
    name: entity.name,
    phone: entity.phone,
    email: entity.email,
    address: entity.address,
    neighborhood: entity.neighborhood,
    city: entity.city,
    status: entity.status,
    registeredAt: entity.registeredAt,
    visitDate: entity.visitDate,
    originChurch: entity.originChurch,
    latitude: entity.latitude,
    longitude: entity.longitude,
    assignedCellId: entity.assignedCellId,
  );
}
