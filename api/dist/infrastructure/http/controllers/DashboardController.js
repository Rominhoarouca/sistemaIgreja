"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.DashboardController = void 0;
class DashboardController {
    statsUseCase;
    visitorRepo;
    constructor(statsUseCase, visitorRepo) {
        this.statsUseCase = statsUseCase;
        this.visitorRepo = visitorRepo;
    }
    getStats = async (_req, res) => {
        const stats = await this.statsUseCase.execute();
        res.json({ stats });
    };
    getMonthlyStats = async (_req, res) => {
        const months = await this.visitorRepo.countByMonth(6);
        res.json({ months });
    };
}
exports.DashboardController = DashboardController;
