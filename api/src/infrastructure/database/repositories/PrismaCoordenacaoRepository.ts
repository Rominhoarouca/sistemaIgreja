import type { PrismaClient } from '@prisma/client';
import type {
  ICoordenacaoRepository,
  CreateCoordenacaoData,
  UpdateCoordenacaoData,
} from '@domain/repositories/ICoordenacaoRepository';
import type { Coordenacao, CoordenacaoWithDetails } from '@domain/entities/Coordenacao';

export class PrismaCoordenacaoRepository implements ICoordenacaoRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async findAll(): Promise<CoordenacaoWithDetails[]> {
    const rows = await this.prisma.coordenacao.findMany({
      orderBy: { name: 'asc' },
      include: {
        coordinador: { select: { id: true, name: true } },
        supervisores: { select: { id: true, name: true, email: true } },
      },
    });

    return rows.map((r) => ({
      id: r.id,
      name: r.name,
      color: r.color,
      coordinadorId: r.coordinadorId,
      createdAt: r.createdAt,
      updatedAt: r.updatedAt,
      coordinadorName: r.coordinador.name,
      supervisoresCount: r.supervisores.length,
      supervisores: r.supervisores,
    }));
  }

  async findById(id: string): Promise<Coordenacao | null> {
    const r = await this.prisma.coordenacao.findUnique({ where: { id } });
    return r ?? null;
  }

  async findByCoordinadorId(coordinadorId: string): Promise<Coordenacao | null> {
    const r = await this.prisma.coordenacao.findUnique({ where: { coordinadorId } });
    return r ?? null;
  }

  async create(data: CreateCoordenacaoData): Promise<Coordenacao> {
    const r = await this.prisma.coordenacao.create({
      data: {
        name: data.name,
        color: data.color,
        coordinadorId: data.coordinadorId,
      },
    });
    return r;
  }

  async update(id: string, data: UpdateCoordenacaoData): Promise<Coordenacao> {
    const r = await this.prisma.coordenacao.update({
      where: { id },
      data: {
        ...(data.name !== undefined && { name: data.name }),
        ...(data.color !== undefined && { color: data.color }),
      },
    });
    return r;
  }

  async delete(id: string): Promise<void> {
    // Unlink supervisors first
    await this.prisma.user.updateMany({
      where: { coordenacaoId: id },
      data: { coordenacaoId: null },
    });
    await this.prisma.coordenacao.delete({ where: { id } });
  }
}
