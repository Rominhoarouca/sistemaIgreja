import '../../domain/entities/cell_entity.dart';

/// Data model — Cell (JSON serializable)
class CellModel extends CellEntity {
  const CellModel({
    required super.id,
    required super.name,
    required super.leaderId,
    required super.leaderName,
    required super.address,
    required super.neighborhood,
    required super.city,
    required super.dayOfWeek,
    required super.meetingTime,
    required super.isActive,
    super.leaderPhone,
    super.latitude,
    super.longitude,
    super.maxCapacity,
    super.currentCount,
    super.distanceKm,
  });

  factory CellModel.fromJson(Map<String, dynamic> json) => CellModel(
    id: json['id'] as String,
    name: json['name'] as String,
    leaderId: json['leaderId'] as String,
    leaderName: json['leaderName'] as String? ?? '',
    leaderPhone: null,
    address: json['address'] as String,
    neighborhood: json['neighborhood'] as String,
    city: json['city'] as String,
    latitude: (json['latitude'] as num?)?.toDouble(),
    longitude: (json['longitude'] as num?)?.toDouble(),
    dayOfWeek: CellDayOfWeek.fromString(json['dayOfWeek'] as String),
    meetingTime: json['time'] as String,
    maxCapacity: json['maxCapacity'] as int?,
    currentCount: json['currentCount'] as int? ?? 0,
    isActive: true,
    distanceKm: (json['distanceKm'] as num?)?.toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'leaderId': leaderId,
    'address': address,
    'neighborhood': neighborhood,
    'city': city,
    'latitude': latitude,
    'longitude': longitude,
    'dayOfWeek': dayOfWeek.name,
    'time': meetingTime,
    'maxCapacity': maxCapacity,
  };
}
