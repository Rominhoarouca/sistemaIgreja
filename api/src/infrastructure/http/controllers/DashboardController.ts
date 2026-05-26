import type { Request, Response } from 'express';
import type { GetDashboardStatsUseCase } from '@application/usecases/dashboard/GetDashboardStatsUseCase';
import type { IVisitorRepository } from '@domain/repositories/IVisitorRepository';

export class DashboardController {
  constructor(
    private readonly statsUseCase: GetDashboardStatsUseCase,
    private readonly visitorRepo: IVisitorRepository,
  ) {}

  getStats = async (_req: Request, res: Response): Promise<void> => {
    const stats = await this.statsUseCase.execute();
    res.json({ stats });
  };

  getMonthlyStats = async (_req: Request, res: Response): Promise<void> => {
    const months = await this.visitorRepo.countByMonth(6);
    res.json({ months });
  };
}
