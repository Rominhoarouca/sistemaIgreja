import type { PrismaClient } from '@prisma/client';
import type { ICellRepository } from '@domain/repositories/ICellRepository';
import type { Cell, CellWithDistance, NearbySearchParams, CreateCellData } from '@domain/entities/Cell';

export class PrismaCellRepository implements ICellRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async findById(id: string): Promise<Cell | null> {
    const row = await this.prisma.cell.findUnique({
      where: { id },
      include: { leader: { select: { name: true } }, _count: { select: { members: true } } },
    });
    return row ? this.mapRow(row) : null;
  }

  async findAll(): Promise<Cell[]> {
    const rows = await this.prisma.cell.findMany({
      include: { leader: { select: { name: true } }, _count: { select: { members: true } } },
      orderBy: { name: 'asc' },
    });
    return rows.map((r) => this.mapRow(r));
  }

  // Haversine formula in raw SQL for nearby search
  async findNearby(params: NearbySearchParams): Promise<CellWithDistance[]> {
    const { latitude, longitude, radiusKm } = params;

    const rows = await this.prisma.$queryRaw<
      Array<{
        id: string;
        name: string;
        leader_id: string;
        address: string;
        neighborhood: string;
        city: string;
        day_of_week: string;
        time: string;
        max_capacity: number;
        latitude: number | null;
        longitude: number | null;
        created_at: Date;
        updated_at: Date;
        member_count: bigint;
        distance_km: number;
      }>
    >`
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
      dayOfWeek: r.day_of_week as Cell['dayOfWeek'],
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

  async create(data: CreateCellData): Promise<Cell> {
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

  async update(id: string, data: Partial<CreateCellData>): Promise<Cell> {
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

  async delete(id: string): Promise<void> {
    await this.prisma.cell.delete({ where: { id } });
  }

  async count(): Promise<number> {
    return this.prisma.cell.count();
  }

  private mapRow(row: {
    id: string;
    name: string;
    leaderId: string;
    leader?: { name: string } | null;
    address: string;
    neighborhood: string;
    city: string;
    dayOfWeek: string;
    time: string;
    maxCapacity: number;
    latitude: number | null;
    longitude: number | null;
    createdAt: Date;
    updatedAt: Date;
    _count: { members: number };
  }): Cell {
    return {
      id: row.id,
      name: row.name,
      leaderId: row.leaderId,
      leaderName: row.leader?.name,
      address: row.address,
      neighborhood: row.neighborhood,
      city: row.city,
      dayOfWeek: row.dayOfWeek as Cell['dayOfWeek'],
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
