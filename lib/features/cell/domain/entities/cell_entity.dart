import 'package:equatable/equatable.dart';

/// Domain entity — Cell group
class CellEntity extends Equatable {
  const CellEntity({
    required this.id,
    required this.name,
    required this.leaderId,
    required this.leaderName,
    required this.address,
    required this.neighborhood,
    required this.city,
    required this.dayOfWeek,
    required this.meetingTime,
    required this.isActive,
    this.leaderPhone,
    this.latitude,
    this.longitude,
    this.maxCapacity,
    this.currentCount = 0,
    this.distanceKm,
  });

  final String id;
  final String name;
  final String leaderId;
  final String leaderName;
  final String address;
  final String neighborhood;
  final String city;
  final CellDayOfWeek dayOfWeek;
  final String meetingTime;
  final bool isActive;

  // Optional
  final String? leaderPhone;
  final double? latitude;
  final double? longitude;
  final int? maxCapacity;
  final int currentCount;
  final double? distanceKm;

  bool get hasCapacity => maxCapacity == null || currentCount < maxCapacity!;

  String get formattedDistance => distanceKm != null
      ? distanceKm! < 1
            ? '${(distanceKm! * 1000).round()}m'
            : '${distanceKm!.toStringAsFixed(1)}km'
      : '';

  @override
  List<Object?> get props => [id];
}

enum CellDayOfWeek {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday;

  static CellDayOfWeek fromString(String value) =>
      switch (value.toLowerCase()) {
        'segunda' || 'monday' => monday,
        'terca' || 'tuesday' => tuesday,
        'quarta' || 'wednesday' => wednesday,
        'quinta' || 'thursday' => thursday,
        'sexta' || 'friday' => friday,
        'sabado' || 'saturday' => saturday,
        _ => sunday,
      };

  String get label => switch (this) {
    CellDayOfWeek.monday => 'Segunda-feira',
    CellDayOfWeek.tuesday => 'Terça-feira',
    CellDayOfWeek.wednesday => 'Quarta-feira',
    CellDayOfWeek.thursday => 'Quinta-feira',
    CellDayOfWeek.friday => 'Sexta-feira',
    CellDayOfWeek.saturday => 'Sábado',
    CellDayOfWeek.sunday => 'Domingo',
  };

  String get shortLabel => switch (this) {
    CellDayOfWeek.monday => 'Seg',
    CellDayOfWeek.tuesday => 'Ter',
    CellDayOfWeek.wednesday => 'Qua',
    CellDayOfWeek.thursday => 'Qui',
    CellDayOfWeek.friday => 'Sex',
    CellDayOfWeek.saturday => 'Sáb',
    CellDayOfWeek.sunday => 'Dom',
  };
}
