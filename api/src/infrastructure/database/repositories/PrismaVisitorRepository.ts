import type { PrismaClient, Prisma } from '@prisma/client';
import type { IVisitorRepository } from '@domain/repositories/IVisitorRepository';
import type {
  Visitor,
  CreateVisitorData,
  UpdateVisitorStatusData,
  VisitorFilters,
  PaginatedVisitors,
} from '@domain/entities/Visitor';

export class PrismaVisitorRepository implements IVisitorRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async findById(id: string): Promise<Visitor | null> {
    const row = await this.prisma.visitor.findUnique({
      where: { id },
      include: { convertedMember: { select: { id: true } } },
    });
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

  async create(data: CreateVisitorData): Promise<Visitor> {
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

  async updateStatus(id: string, data: UpdateVisitorStatusData): Promise<Visitor> {
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

  private mapRow(row: {
    id: string;
    name: string;
    phone: string;
    email: string | null;
    address: string | null;
    neighborhood: string | null;
    city: string | null;
    originChurch: string | null;
    status: string;
    leaderId: string | null;
    cellId: string | null;
    referredById: string | null;
    convertedMember?: { id: string } | null;
    createdAt: Date;
    updatedAt: Date;
  }): Visitor {
    return {
      id: row.id,
      name: row.name,
      phone: row.phone,
      email: row.email,
      address: row.address,
      neighborhood: row.neighborhood,
      city: row.city,
      originChurch: row.originChurch,
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
