import type { Request, Response } from 'express';
import type { GetDashboardStatsUseCase } from '@application/usecases/dashboard/GetDashboardStatsUseCase';

export class DashboardController {
  constructor(private readonly statsUseCase: GetDashboardStatsUseCase) {}

  getStats = async (_req: Request, res: Response): Promise<void> => {
    const stats = await this.statsUseCase.execute();
    res.json({ stats });
  };
}
