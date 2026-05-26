"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.GetDashboardStatsUseCase = void 0;
class GetDashboardStatsUseCase {
    visitorRepo;
    cellRepo;
    attendanceRepo;
    userRepo;
    constructor(visitorRepo, cellRepo, attendanceRepo, userRepo) {
        this.visitorRepo = visitorRepo;
        this.cellRepo = cellRepo;
        this.attendanceRepo = attendanceRepo;
        this.userRepo = userRepo;
    }
    async execute() {
        const [byStatus, cells, avgRate, newThisMonth, leaders] = await Promise.all([
            this.visitorRepo.countByStatus(),
            this.cellRepo.findAll(),
            this.attendanceRepo.getAverageAttendanceRate(),
            this.visitorRepo.countNewThisMonth(),
            this.userRepo.listLeaders(),
        ]);
        const total = Object.values(byStatus).reduce((s, v) => s + v, 0);
        const integrated = byStatus['integrado'] ?? 0;
        const forwarded = (byStatus['em_acompanhamento'] ?? 0) + (byStatus['integrado'] ?? 0);
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
exports.GetDashboardStatsUseCase = GetDashboardStatsUseCase;
