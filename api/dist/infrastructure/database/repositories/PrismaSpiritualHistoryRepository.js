"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PrismaSpiritualHistoryRepository = void 0;
class PrismaSpiritualHistoryRepository {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    async findByVisitor(visitorId) {
        return this.prisma.spiritualHistory.findMany({
            where: { visitorId },
            orderBy: { date: 'asc' },
        });
    }
    async findByCellId(cellId) {
        const rows = await this.prisma.spiritualHistory.findMany({
            where: { visitor: { cellId } },
            include: { visitor: { select: { name: true } } },
            orderBy: { date: 'desc' },
        });
        return rows.map((r) => ({
            id: r.id,
            visitorId: r.visitorId,
            visitorName: r.visitor.name,
            eventType: r.eventType,
            description: r.description,
            date: r.date,
            recordedById: r.recordedById,
            createdAt: r.createdAt,
        }));
    }
    async add(data) {
        return this.prisma.spiritualHistory.create({
            data: {
                visitorId: data.visitorId,
                eventType: data.eventType,
                description: data.description ?? null,
                date: data.date,
                recordedById: data.recordedById,
            },
        });
    }
}
exports.PrismaSpiritualHistoryRepository = PrismaSpiritualHistoryRepository;
