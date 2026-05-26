"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PrismaVisitorRepository = void 0;
class PrismaVisitorRepository {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    async findById(id) {
        const row = await this.prisma.visitor.findUnique({
            where: { id },
            include: { convertedMember: { select: { id: true } } },
        });
        return row ? this.mapRow(row) : null;
    }
    async findMany(filters) {
        const page = filters.page ?? 1;
        const pageSize = filters.pageSize ?? 20;
        const where = {
            ...(filters.leaderId ? { leaderId: filters.leaderId } : {}),
            ...(filters.cellId ? { cellId: filters.cellId } : {}),
            ...(filters.status ? { status: filters.status } : {}),
            ...(filters.search
                ? {
                    OR: [
                        { name: { contains: filters.search, mode: 'insensitive' } },
                        { phone: { contains: filters.search } },
                        { email: { contains: filters.search, mode: 'insensitive' } },
                    ],
                }
                : {}),
        };
        const [total, rows] = await Promise.all([
            this.prisma.visitor.count({ where }),
            this.prisma.visitor.findMany({
                where,
                include: { convertedMember: { select: { id: true } } },
                orderBy: { createdAt: 'desc' },
                skip: (page - 1) * pageSize,
                take: pageSize,
            }),
        ]);
        return {
            data: rows.map((r) => this.mapRow(r)),
            total,
            page,
            pageSize,
            totalPages: Math.ceil(total / pageSize),
        };
    }
    async create(data) {
        const row = await this.prisma.visitor.create({
            data: {
                name: data.name,
                phone: data.phone,
                ...(data.email !== undefined ? { email: data.email } : {}),
                ...(data.address !== undefined ? { address: data.address } : {}),
                ...(data.neighborhood !== undefined ? { neighborhood: data.neighborhood } : {}),
                ...(data.city !== undefined ? { city: data.city } : {}),
                ...(data.originChurch !== undefined ? { originChurch: data.originChurch } : {}),
                ...(data.leaderId !== undefined ? { leaderId: data.leaderId } : {}),
                ...(data.cellId !== undefined ? { cellId: data.cellId } : {}),
                ...(data.referredById !== undefined ? { referredById: data.referredById } : {}),
            },
            include: { convertedMember: { select: { id: true } } },
        });
        return this.mapRow(row);
    }
    async updateStatus(id, data) {
        const row = await this.prisma.visitor.update({
            where: { id },
            data: {
                status: data.status,
                ...(data.leaderId !== undefined ? { leaderId: data.leaderId } : {}),
                ...(data.cellId !== undefined ? { cellId: data.cellId } : {}),
            },
            include: { convertedMember: { select: { id: true } } },
        });
        return this.mapRow(row);
    }
    async countByStatus() {
        const grouped = await this.prisma.visitor.groupBy({
            by: ['status'],
            _count: { _all: true },
        });
        return Object.fromEntries(grouped.map((g) => [g.status, g._count._all]));
    }
    async countNewThisMonth() {
        const start = new Date();
        start.setDate(1);
        start.setHours(0, 0, 0, 0);
        return this.prisma.visitor.count({
            where: { createdAt: { gte: start } },
        });
    }
    async countByMonth(months) {
        const rows = await this.prisma.$queryRaw `
      SELECT
        TO_CHAR(DATE_TRUNC('month', created_at), 'YYYY-MM') AS month,
        COUNT(*)::bigint AS total,
        SUM(CASE WHEN status = 'integrado' THEN 1 ELSE 0 END)::bigint AS integrated
      FROM visitors
      WHERE created_at >= DATE_TRUNC('month', NOW() - (${months - 1} || ' months')::interval)
      GROUP BY DATE_TRUNC('month', created_at)
      ORDER BY DATE_TRUNC('month', created_at)
    `;
        return rows.map((r) => ({
            month: r.month,
            total: Number(r.total),
            integrated: Number(r.integrated),
        }));
    }
    mapRow(row) {
        return {
            id: row.id,
            name: row.name,
            phone: row.phone,
            email: row.email,
            address: row.address,
            neighborhood: row.neighborhood,
            city: row.city,
            originChurch: row.originChurch,
            status: row.status,
            leaderId: row.leaderId,
            cellId: row.cellId,
            referredById: row.referredById,
            memberId: row.convertedMember?.id ?? null,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
        };
    }
}
exports.PrismaVisitorRepository = PrismaVisitorRepository;
