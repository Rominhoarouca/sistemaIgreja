import type { PrismaClient } from '@prisma/client';
import type { CellMember, CreateCellMemberData } from '@domain/entities/CellMember';
import type { ICellMemberRepository } from '@domain/repositories/ICellMemberRepository';
import { AppError } from '@shared/errors/AppError';

export class PrismaCellMemberRepository implements ICellMemberRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async findByCellId(cellId: string): Promise<CellMember[]> {
    const rows = await this.prisma.cellMember.findMany({
      where: { cellId },
      orderBy: { createdAt: 'desc' },
    });

    return rows.map((row) => this.mapRow(row));
  }

  async create(data: CreateCellMemberData): Promise<CellMember> {
    const row = await this.prisma.cellMember.create({
      data: {
        cellId: data.cellId,
        name: data.name,
        phone: data.phone,
        ...(data.email !== undefined ? { email: data.email } : {}),
        ...(data.address !== undefined ? { address: data.address } : {}),
        ...(data.neighborhood !== undefined ? { neighborhood: data.neighborhood } : {}),
        ...(data.city !== undefined ? { city: data.city } : {}),
        ...(data.leaderId !== undefined ? { leaderId: data.leaderId } : {}),
      },
    });

    return this.mapRow(row);
  }

  async convertVisitorToMember(visitorId: string, cellId?: string): Promise<CellMember> {
    const visitor = await this.prisma.visitor.findUnique({ where: { id: visitorId } });

    if (!visitor) {
      throw AppError.notFound('Visitante não encontrado');
    }

    const targetCellId = cellId ?? visitor.cellId;
    if (!targetCellId) {
      throw new AppError('Visitante sem célula. Informe uma célula para converter.', 400, 'CELL_REQUIRED');
    }

    const existing = await this.prisma.cellMember.findUnique({
      where: { sourceVisitorId: visitorId },
    });

    if (existing) {
      return this.mapRow(existing);
    }

    const member = await this.prisma.$transaction(async (tx) => {
      const created = await tx.cellMember.create({
        data: {
          cellId: targetCellId,
          name: visitor.name,
          phone: visitor.phone,
          email: visitor.email,
          address: visitor.address,
          neighborhood: visitor.neighborhood,
          city: visitor.city,
          leaderId: visitor.leaderId,
          sourceVisitorId: visitor.id,
        },
      });

      await tx.visitor.update({
        where: { id: visitor.id },
        data: {
          status: 'integrado',
          cellId: targetCellId,
        },
      });

      return created;
    });

    return this.mapRow(member);
  }

  private mapRow(row: {
    id: string;
    cellId: string;
    name: string;
    phone: string;
    email: string | null;
    address: string | null;
    neighborhood: string | null;
    city: string | null;
    leaderId: string | null;
    sourceVisitorId: string | null;
    createdAt: Date;
    updatedAt: Date;
  }): CellMember {
    return {
      id: row.id,
      cellId: row.cellId,
      name: row.name,
      phone: row.phone,
      email: row.email,
      address: row.address,
      neighborhood: row.neighborhood,
      city: row.city,
      leaderId: row.leaderId,
      sourceVisitorId: row.sourceVisitorId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    };
  }
}
