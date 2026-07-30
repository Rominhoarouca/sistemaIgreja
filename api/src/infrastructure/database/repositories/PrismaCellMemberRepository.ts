import type { PrismaClient } from '@prisma/client';
import type { CellMember, CreateCellMemberData } from '@domain/entities/CellMember';
import type { ICellMemberRepository } from '@domain/repositories/ICellMemberRepository';
import { AppError } from '@shared/errors/AppError';

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

export class PrismaCellMemberRepository implements ICellMemberRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async findByCellId(cellId: string): Promise<CellMember[]> {
    const rows = await this.prisma.cellMember.findMany({
      where: { cellId },
      include: { ...bairroInclude },
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
        ...(data.bairroId !== undefined ? { bairroId: data.bairroId } : {}),
        ...(data.birthDate !== undefined ? { birthDate: data.birthDate } : {}),
        ...(data.gender !== undefined ? { gender: data.gender } : {}),
        ...(data.maritalStatus !== undefined ? { maritalStatus: data.maritalStatus } : {}),
        ...(data.leaderId !== undefined ? { leaderId: data.leaderId } : {}),
      },
      include: { ...bairroInclude },
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
      include: { ...bairroInclude },
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
          bairroId: visitor.bairroId,
          birthDate: visitor.birthDate,
          gender: visitor.gender,
          maritalStatus: visitor.maritalStatus,
          leaderId: visitor.leaderId,
          sourceVisitorId: visitor.id,
        },
        include: { ...bairroInclude },
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
    bairroId: string | null;
    bairro?: BairroRow;
    birthDate?: Date | null;
    gender?: CellMember['gender'];
    maritalStatus?: string | null;
    leaderId: string | null;
    sourceVisitorId: string | null;
    createdAt: Date;
    updatedAt: Date;
  }): CellMember {
    const loc = deriveLocation(row.bairro ?? null);
    return {
      id: row.id,
      cellId: row.cellId,
      name: row.name,
      phone: row.phone,
      email: row.email,
      address: row.address,
      bairroId: row.bairroId,
      neighborhood: loc.neighborhood,
      city: loc.city,
      state: loc.state,
      birthDate: row.birthDate ?? null,
      gender: row.gender ?? null,
      maritalStatus: row.maritalStatus ?? null,
      leaderId: row.leaderId,
      sourceVisitorId: row.sourceVisitorId,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    };
  }
}
