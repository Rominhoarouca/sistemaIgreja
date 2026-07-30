import type { PrismaClient, Prisma } from '@prisma/client';
import type { IVisitorRepository } from '@domain/repositories/IVisitorRepository';
import { getEffectiveChurchId } from '@shared/context/tenant-context';
import type {
  Visitor,
  CreateVisitorData,
  UpdateVisitorStatusData,
  VisitorFilters,
  PaginatedVisitors,
} from '@domain/entities/Visitor';

type BairroRow = {
  id: string;
  name: string;
  cidade: { id: string; name: string; estado: { id: string; name: string; uf: string } };
} | null;

const bairroInclude = {
  bairro: {
    select: {
      id: true, name: true,
      cidade: { select: { id: true, name: true, estado: { select: { id: true, name: true, uf: true } } } },
    },
  },
} as const;

function deriveLocation(bairro: BairroRow): { neighborhood: string | null; city: string | null; state: string | null } {
  if (!bairro) return { neighborhood: null, city: null, state: null };
  return { neighborhood: bairro.name, city: bairro.cidade.name, state: bairro.cidade.estado.uf };
}

export class PrismaVisitorRepository implements IVisitorRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async findById(id: string): Promise<Visitor | null> {
    const row = await this.prisma.visitor.findUnique({
      where: { id },
      include: { convertedMember: { select: { id: true } }, ...bairroInclude },
    }) as any;
    return row ? this.mapRow(row) : null;
  }

  async findMany(filters: VisitorFilters): Promise<PaginatedVisitors> {
    const page = filters.page ?? 1;
    const pageSize = filters.pageSize ?? 20;

    const where: Prisma.VisitorWhereInput = {
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
        include: { convertedMember: { select: { id: true } }, ...bairroInclude },
        orderBy: { createdAt: 'desc' },
        skip: (page - 1) * pageSize,
        take: pageSize,
      }) as any,
    ]);

    return {
      data: rows.map((r: any) => this.mapRow(r)),
      total,
      page,
      pageSize,
      totalPages: Math.ceil(total / pageSize),
    };
  }

  async create(data: CreateVisitorData): Promise<Visitor> {
    const row = await this.prisma.visitor.create({
      data: {
        name: data.name,
        phone: data.phone,
        ...(data.email !== undefined ? { email: data.email } : {}),
        ...(data.address !== undefined ? { address: data.address } : {}),
        ...(data.numero !== undefined ? { numero: data.numero } : {}),
        ...(data.complemento !== undefined ? { complemento: data.complemento } : {}),
        ...(data.bairroId !== undefined ? { bairroId: data.bairroId } : {}),
        ...(data.originChurch !== undefined ? { originChurch: data.originChurch } : {}),
        ...(data.birthDate !== undefined ? { birthDate: data.birthDate } : {}),
        ...(data.gender !== undefined ? { gender: data.gender } : {}),
        ...(data.maritalStatus !== undefined ? { maritalStatus: data.maritalStatus } : {}),
        ...(data.isBaptized !== undefined ? { isBaptized: data.isBaptized } : {}),
        ...(data.knownPersonName !== undefined ? { knownPersonName: data.knownPersonName } : {}),
        ...(data.interests !== undefined ? { interests: data.interests } : {}),
        ...(data.leaderId !== undefined ? { leaderId: data.leaderId } : {}),
        ...(data.cellId !== undefined ? { cellId: data.cellId } : {}),
        ...(data.referredById !== undefined ? { referredById: data.referredById } : {}),
      },
      include: { convertedMember: { select: { id: true } }, ...bairroInclude },
    }) as any;
    return this.mapRow(row);
  }

  async updateStatus(id: string, data: UpdateVisitorStatusData): Promise<Visitor> {
    const row = await this.prisma.visitor.update({
      where: { id },
      data: {
        status: data.status,
        ...(data.leaderId !== undefined ? { leaderId: data.leaderId } : {}),
        ...(data.cellId !== undefined ? { cellId: data.cellId } : {}),
      },
      include: { convertedMember: { select: { id: true } }, ...bairroInclude },
    }) as any;
    return this.mapRow(row);
  }

  async countByStatus(): Promise<Record<string, number>> {
    const grouped = await this.prisma.visitor.groupBy({
      by: ['status'],
      _count: { _all: true },
    });
    return Object.fromEntries(grouped.map((g) => [g.status, g._count._all]));
  }

  async countNewThisMonth(): Promise<number> {
    const start = new Date();
    start.setDate(1);
    start.setHours(0, 0, 0, 0);
    return this.prisma.visitor.count({
      where: { createdAt: { gte: start } },
    });
  }

  async countByMonth(
    months: number,
  ): Promise<Array<{ month: string; total: number; integrated: number }>> {
    const churchId = getEffectiveChurchId() ?? null;
    const rows = await this.prisma.$queryRaw<
      Array<{ month: string; total: bigint; integrated: bigint }>
    >`
      SELECT
        TO_CHAR(DATE_TRUNC('month', created_at), 'YYYY-MM') AS month,
        COUNT(*)::bigint AS total,
        SUM(CASE WHEN status = 'integrado' THEN 1 ELSE 0 END)::bigint AS integrated
      FROM visitors
      WHERE created_at >= DATE_TRUNC('month', NOW() - (${months - 1} || ' months')::interval)
        AND (${churchId}::text IS NULL OR church_id = ${churchId})
      GROUP BY DATE_TRUNC('month', created_at)
      ORDER BY DATE_TRUNC('month', created_at)
    `;
    return rows.map((r) => ({
      month: r.month,
      total: Number(r.total),
      integrated: Number(r.integrated),
    }));
  }

  private mapRow(row: {
    id: string;
    name: string;
    phone: string;
    email: string | null;
    address: string | null;
    numero: string | null;
    complemento: string | null;
    bairroId: string | null;
    bairro?: BairroRow;
    originChurch: string | null;
    birthDate?: Date | null;
    gender?: Visitor['gender'];
    maritalStatus?: string | null;
    isBaptized?: boolean;
    knownPersonName?: string | null;
    interests?: string[];
    status: string;
    leaderId: string | null;
    cellId: string | null;
    referredById: string | null;
    convertedMember?: { id: string } | null;
    createdAt: Date;
    updatedAt: Date;
  }): Visitor {
    const loc = deriveLocation(row.bairro ?? null);
    return {
      id: row.id,
      name: row.name,
      phone: row.phone,
      email: row.email,
      address: row.address,
      numero: row.numero,
      complemento: row.complemento,
      bairroId: row.bairroId,
      neighborhood: loc.neighborhood,
      city: loc.city,
      state: loc.state,
      originChurch: row.originChurch,
      birthDate: row.birthDate ?? null,
      gender: row.gender ?? null,
      maritalStatus: row.maritalStatus ?? null,
      isBaptized: row.isBaptized ?? false,
      knownPersonName: row.knownPersonName ?? null,
      interests: row.interests ?? [],
      status: row.status as Visitor['status'],
      leaderId: row.leaderId,
      cellId: row.cellId,
      referredById: row.referredById,
      memberId: row.convertedMember?.id ?? null,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    };
  }
}
