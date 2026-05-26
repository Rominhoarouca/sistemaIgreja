import type { IVisitorRepository } from '@domain/repositories/IVisitorRepository';
import type { ICellRepository } from '@domain/repositories/ICellRepository';
import type { IAttendanceRepository } from '@domain/repositories/IAttendanceRepository';
import type { IUserRepository } from '@domain/repositories/IUserRepository';
import type { DashboardStats } from '@domain/entities/DashboardStats';

export class GetDashboardStatsUseCase {
  constructor(
    private readonly visitorRepo: IVisitorRepository,
    private readonly cellRepo: ICellRepository,
    private readonly attendanceRepo: IAttendanceRepository,
    private readonly userRepo: IUserRepository,
  ) {}

  async execute(): Promise<DashboardStats> {
    const [byStatus, cells, avgRate, newThisMonth, leaders] = await Promise.all([
      this.visitorRepo.countByStatus(),
      this.cellRepo.findAll(),
      this.attendanceRepo.getAverageAttendanceRate(),
      this.visitorRepo.countNewThisMonth(),
      this.userRepo.listLeaders(),
    ]);

    const total = Object.values(byStatus).reduce((s, v) => s + v, 0);
    const integrated = byStatus['integrado'] ?? 0;
    const forwarded =
      (byStatus['em_acompanhamento'] ?? 0) + (byStatus['integrado'] ?? 0);

    return {
      totalVisitors: total,
      totalCells: cells.length,
      totalLeaders: leaders.length,
      integratedVisitors: integrated,
      forwardedVisitors: forwarded,
      newVisitorsThisMonth: newThisMonth,
      averageAttendanceRate: Math.round(avgRate * 10) / 10,
      activeCells: cells.map((c) => ({
        cellId: c.id,
        cellName: c.name,
        leaderName: c.leaderName ?? '',
        visitorCount: c.currentCount,
        attendanceRate: 0,
      })),
    };
  }
}
