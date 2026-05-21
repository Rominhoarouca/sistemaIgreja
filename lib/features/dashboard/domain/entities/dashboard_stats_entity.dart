import 'package:equatable/equatable.dart';

/// Domain entity — Dashboard summary stats
class DashboardStatsEntity extends Equatable {
  const DashboardStatsEntity({
    required this.totalVisitors,
    required this.newVisitors,
    required this.referrals,
    required this.integrated,
    required this.averageAttendancePercent,
    required this.activeLeaders,
    required this.activeCells,
    this.visitorsThisMonth,
    this.visitorsLastMonth,
  });

  final int totalVisitors;
  final int newVisitors;
  final int referrals;
  final int integrated;
  final double averageAttendancePercent;
  final int activeLeaders;
  final int activeCells;
  final int? visitorsThisMonth;
  final int? visitorsLastMonth;

  double get integrationRate =>
      totalVisitors == 0 ? 0 : integrated / totalVisitors;

  @override
  List<Object?> get props => [
    totalVisitors,
    integrated,
    averageAttendancePercent,
  ];
}
