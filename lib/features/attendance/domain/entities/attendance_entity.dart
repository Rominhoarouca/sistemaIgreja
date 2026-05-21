import 'package:equatable/equatable.dart';

/// Domain entity — Attendance record
class AttendanceEntity extends Equatable {
  const AttendanceEntity({
    required this.id,
    required this.visitorId,
    required this.visitorName,
    required this.cellId,
    required this.meetingDate,
    required this.isPresent,
  });

  final String id;
  final String visitorId;
  final String visitorName;
  final String cellId;
  final DateTime meetingDate;
  final bool isPresent;

  @override
  List<Object?> get props => [id, visitorId, meetingDate];
}
