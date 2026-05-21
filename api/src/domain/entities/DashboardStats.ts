export interface DashboardStats {
  readonly totalVisitors: number;
  readonly totalCells: number;
  readonly totalLeaders: number;
  readonly integratedVisitors: number;
  readonly newVisitorsThisMonth: number;
  readonly averageAttendanceRate: number;
  readonly activeCells: Array<{
    readonly cellId: string;
    readonly cellName: string;
    readonly leaderName: string;
    readonly visitorCount: number;
    readonly attendanceRate: number;
  }>;
}
