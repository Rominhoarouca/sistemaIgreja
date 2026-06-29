import type { PrismaClient } from '@prisma/client';
import type { ICellRepository } from '@domain/repositories/ICellRepository';
import type { Cell, CellWithDistance, NearbySearchParams, CreateCellData } from '@domain/entities/Cell';

type BairroRow = {
  id: string;
  name: string;
  cidade: {
    id: string;
    name: string;
    estado: { id: string; name: string; uf: string };
  };
} | null;

const bairroInclude = {
  bairro: {
    select: {
      id: true,
      name: true,
      cidade: { select: { id: true, name: true, estado: { select: { id: true, name: true, uf: true } } } },
    },
  },
  cellType: { select: { id: true, name: true } },
} as const;

function deriveLocation(bairro: BairroRow): { neighborhood: string; city: string; state: string } {
  return {
    neighborhood: bairro?.name ?? '',
    city: bairro?.cidade.name ?? '',
    state: bairro?.cidade.estado.uf ?? '',
  };
}

export class PrismaCellRepository implements ICellRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async findById(id: string): Promise<Cell | null> {
    const row = await this.prisma.cell.findUnique({
      where: { id },
      include: { leader: { select: { name: true } }, _count: { select: { members: true } }, ...bairroInclude },
    });
    return row ? this.mapRow(row) : null;
  }

  async findAll(): Promise<Cell[]> {
    const rows = await this.prisma.cell.findMany({
      include: { leader: { select: { name: true } }, _count: { select: { members: true } }, ...bairroInclude },
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
        bairro_id: string | null;
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
        c.bairro_id,
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

    // Fetch bairros for nearby cells in bulk
    const bairroIds = rows.map((r) => r.bairro_id).filter((id): id is string => id != null);
    const bairrosMap = new Map<string, BairroRow>();
    if (bairroIds.length > 0) {
      const bairros = await this.prisma.bairro.findMany({
        where: { id: { in: bairroIds } },
        select: {
          id: true, name: true,
          cidade: { select: { id: true, name: true, estado: { select: { id: true, name: true, uf: true } } } },
        },
      });
      for (const b of bairros) bairrosMap.set(b.id, b);
    }

    return rows.map((r) => {
      const bairro = r.bairro_id ? (bairrosMap.get(r.bairro_id) ?? null) : null;
      const loc = deriveLocation(bairro);
      return {
        id: r.id,
        name: r.name,
        leaderId: r.leader_id,
        cellTypeId: null,
        cellTypeName: null,
        address: r.address,
        bairroId: r.bairro_id,
        neighborhood: loc.neighborhood,
        city: loc.city,
        state: loc.state,
        dayOfWeek: r.day_of_week as Cell['dayOfWeek'],
        time: r.time,
        maxCapacity: r.max_capacity,
        currentCount: Number(r.member_count),
        latitude: r.latitude,
        longitude: r.longitude,
        createdAt: r.created_at,
        updatedAt: r.updated_at,
        distanceKm: Number(r.distance_km.toFixed(2)),
      };
    });
  }

  async create(data: CreateCellData): Promise<Cell> {
    const row = await this.prisma.cell.create({
      data: {
        name: data.name,
        leaderId: data.leaderId,
        ...(data.cellTypeId !== undefined && data.cellTypeId !== null ? { cellTypeId: data.cellTypeId } : {}),
        address: data.address,
        ...(data.bairroId !== undefined && data.bairroId !== null ? { bairroId: data.bairroId } : {}),
        dayOfWeek: data.dayOfWeek,
        time: data.time,
        maxCapacity: data.maxCapacity ?? 20,
        latitude: data.latitude ?? null,
        longitude: data.longitude ?? null,
      },
      include: { leader: { select: { name: true } }, _count: { select: { members: true } }, ...bairroInclude },
    });
    return this.mapRow(row);
  }

  async update(id: string, data: Partial<CreateCellData>): Promise<Cell> {
    const row = await this.prisma.cell.update({
      where: { id },
      data: {
        ...(data.name !== undefined && { name: data.name }),
        ...(data.leaderId !== undefined && { leaderId: data.leaderId }),
        ...(data.cellTypeId !== undefined && { cellTypeId: data.cellTypeId }),
        ...(data.address !== undefined && { address: data.address }),
        ...(data.bairroId !== undefined && { bairroId: data.bairroId }),
        ...(data.dayOfWeek !== undefined && { dayOfWeek: data.dayOfWeek }),
        ...(data.time !== undefined && { time: data.time }),
        ...(data.maxCapacity !== undefined && { maxCapacity: data.maxCapacity }),
        ...(data.latitude !== undefined && { latitude: data.latitude }),
        ...(data.longitude !== undefined && { longitude: data.longitude }),
      },
      include: { leader: { select: { name: true } }, _count: { select: { members: true } }, ...bairroInclude },
    });
    return this.mapRow(row);
  }

  async delete(id: string): Promise<void> {
    await this.prisma.cell.delete({ where: { id } });
  }

  async count(): Promise<number> {
    return this.prisma.cell.count();
  }

  async findByLeaderId(leaderId: string): Promise<Cell[]> {
    const rows = await this.prisma.cell.findMany({
      where: { leaderId },
      include: { leader: { select: { name: true } }, _count: { select: { members: true } }, ...bairroInclude },
      orderBy: { name: 'asc' },
    });
    return rows.map((r) => this.mapRow(r));
  }

  private mapRow(row: {
    id: string;
    name: string;
    leaderId: string;
    leader?: { name: string } | null;
    cellTypeId?: string | null;
    cellType?: { id: string; name: string } | null;
    address: string;
    bairroId: string | null;
    bairro?: BairroRow;
    dayOfWeek: string;
    time: string;
    maxCapacity: number;
    latitude: number | null;
    longitude: number | null;
    createdAt: Date;
    updatedAt: Date;
    _count: { members: number };
  }): Cell {
    const loc = deriveLocation(row.bairro ?? null);
    return {
      id: row.id,
      name: row.name,
      leaderId: row.leaderId,
      ...(row.leader?.name !== undefined && { leaderName: row.leader.name }),
      cellTypeId: row.cellTypeId ?? null,
      ...(row.cellType?.name !== undefined && { cellTypeName: row.cellType.name }),
      address: row.address,
      bairroId: row.bairroId,
      estadoId: (row.bairro as any)?.cidade?.estado?.id ?? null,
      cidadeId: (row.bairro as any)?.cidade?.id ?? null,
      neighborhood: loc.neighborhood,
      city: loc.city,
      state: loc.state,
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
