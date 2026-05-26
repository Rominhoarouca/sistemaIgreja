"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PrismaCellRepository = void 0;
class PrismaCellRepository {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    async findById(id) {
        const row = await this.prisma.cell.findUnique({
            where: { id },
            include: { leader: { select: { name: true } }, _count: { select: { members: true } } },
        });
        return row ? this.mapRow(row) : null;
    }
    async findAll() {
        const rows = await this.prisma.cell.findMany({
            include: { leader: { select: { name: true } }, _count: { select: { members: true } } },
            orderBy: { name: 'asc' },
        });
        return rows.map((r) => this.mapRow(r));
    }
    // Haversine formula in raw SQL for nearby search
    async findNearby(params) {
        const { latitude, longitude, radiusKm } = params;
        const rows = await this.prisma.$queryRaw `
      SELECT
        c.id,
        c.name,
        c.leader_id,
        c.address,
        c.neighborhood,
        c.city,
        c.day_of_week,
        c.time,
        c.max_capacity,
        c.latitude,
        c.longitude,
        c.created_at,
        c.updated_at,
        COUNT(m.id) AS member_count,
        (
          6371 * acos(
            cos(radians(${latitude})) *
            cos(radians(c.latitude)) *
            cos(radians(c.longitude) - radians(${longitude})) +
            sin(radians(${latitude})) *
            sin(radians(c.latitude))
          )
        ) AS distance_km
      FROM cells c
      LEFT JOIN cell_members m ON m.cell_id = c.id
      WHERE c.latitude IS NOT NULL AND c.longitude IS NOT NULL
      GROUP BY c.id
      HAVING (
        6371 * acos(
          cos(radians(${latitude})) *
          cos(radians(c.latitude)) *
          cos(radians(c.longitude) - radians(${longitude})) +
          sin(radians(${latitude})) *
          sin(radians(c.latitude))
        )
      ) <= ${radiusKm}
      ORDER BY distance_km ASC
    `;
        return rows.map((r) => ({
            id: r.id,
            name: r.name,
            leaderId: r.leader_id,
            address: r.address,
            neighborhood: r.neighborhood,
            city: r.city,
            dayOfWeek: r.day_of_week,
            time: r.time,
            maxCapacity: r.max_capacity,
            currentCount: Number(r.member_count),
            latitude: r.latitude,
            longitude: r.longitude,
            createdAt: r.created_at,
            updatedAt: r.updated_at,
            distanceKm: Number(r.distance_km.toFixed(2)),
        }));
    }
    async create(data) {
        const row = await this.prisma.cell.create({
            data: {
                name: data.name,
                leaderId: data.leaderId,
                address: data.address,
                neighborhood: data.neighborhood,
                city: data.city,
                dayOfWeek: data.dayOfWeek,
                time: data.time,
                maxCapacity: data.maxCapacity ?? 20,
                latitude: data.latitude ?? null,
                longitude: data.longitude ?? null,
            },
            include: { leader: { select: { name: true } }, _count: { select: { members: true } } },
        });
        return this.mapRow(row);
    }
    async update(id, data) {
        const row = await this.prisma.cell.update({
            where: { id },
            data: {
                ...(data.name !== undefined && { name: data.name }),
                ...(data.leaderId !== undefined && { leaderId: data.leaderId }),
                ...(data.address !== undefined && { address: data.address }),
                ...(data.neighborhood !== undefined && { neighborhood: data.neighborhood }),
                ...(data.city !== undefined && { city: data.city }),
                ...(data.dayOfWeek !== undefined && { dayOfWeek: data.dayOfWeek }),
                ...(data.time !== undefined && { time: data.time }),
                ...(data.maxCapacity !== undefined && { maxCapacity: data.maxCapacity }),
                ...(data.latitude !== undefined && { latitude: data.latitude }),
                ...(data.longitude !== undefined && { longitude: data.longitude }),
            },
            include: { leader: { select: { name: true } }, _count: { select: { members: true } } },
        });
        return this.mapRow(row);
    }
    async delete(id) {
        await this.prisma.cell.delete({ where: { id } });
    }
    async count() {
        return this.prisma.cell.count();
    }
    async findByLeaderId(leaderId) {
        const row = await this.prisma.cell.findFirst({
            where: { leaderId },
            include: { leader: { select: { name: true } }, _count: { select: { members: true } } },
        });
        return row ? this.mapRow(row) : null;
    }
    mapRow(row) {
        return {
            id: row.id,
            name: row.name,
            leaderId: row.leaderId,
            leaderName: row.leader?.name,
            address: row.address,
            neighborhood: row.neighborhood,
            city: row.city,
            dayOfWeek: row.dayOfWeek,
            time: row.time,
            maxCapacity: row.maxCapacity,
            currentCount: row._count.members,
            latitude: row.latitude,
            longitude: row.longitude,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
        };
    }
}
exports.PrismaCellRepository = PrismaCellRepository;
