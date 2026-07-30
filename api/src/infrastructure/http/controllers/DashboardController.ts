import type { Request, Response } from 'express';
import type { GetDashboardStatsUseCase } from '@application/usecases/dashboard/GetDashboardStatsUseCase';
import type { GetDemographicsUseCase } from '@application/usecases/dashboard/GetDemographicsUseCase';
import type { IVisitorRepository } from '@domain/repositories/IVisitorRepository';
import type { IAttendanceRepository } from '@domain/repositories/IAttendanceRepository';

export class DashboardController {
  constructor(
    private readonly statsUseCase: GetDashboardStatsUseCase,
    private readonly visitorRepo: IVisitorRepository,
    private readonly attendanceRepo: IAttendanceRepository,
    private readonly demographicsUseCase: GetDemographicsUseCase,
  ) {}

  getStats = async (_req: Request, res: Response): Promise<void> => {
    const stats = await this.statsUseCase.execute();
    res.json({ stats });
  };

  getMonthlyStats = async (_req: Request, res: Response): Promise<void> => {
    const months = await this.visitorRepo.countByMonth(6);
    res.json({ months });
  };

  getAttendanceByCell = async (_req: Request, res: Response): Promise<void> => {
    const cells = await this.attendanceRepo.getAttendanceRateByCell();
    res.json({ cells });
  };

  getDemographics = async (_req: Request, res: Response): Promise<void> => {
    const demographics = await this.demographicsUseCase.execute();
    res.json({ demographics });
  };
}
