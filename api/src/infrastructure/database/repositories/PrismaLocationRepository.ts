import type { PrismaClient } from '@prisma/client';
import type { ILocationRepository } from '@domain/repositories/ILocationRepository';
import type {
  Estado,
  Cidade,
  Bairro,
  CreateEstadoData,
  CreateCidadeData,
  CreateBairroData,
} from '@domain/entities/Location';

export class PrismaLocationRepository implements ILocationRepository {
  constructor(private readonly prisma: PrismaClient) {}

  // ── Estados ────────────────────────────────────────────────────────────────

  async findAllEstados(): Promise<Estado[]> {
    const rows = await this.prisma.estado.findMany({ orderBy: { name: 'asc' } });
    return rows.map((r) => ({ id: r.id, name: r.name, uf: r.uf, createdAt: r.createdAt }));
  }

  async findEstadoById(id: string): Promise<Estado | null> {
    const row = await this.prisma.estado.findUnique({ where: { id } });
    return row ? { id: row.id, name: row.name, uf: row.uf, createdAt: row.createdAt } : null;
  }

  async createEstado(data: CreateEstadoData): Promise<Estado> {
    const row = await this.prisma.estado.create({
      data: { name: data.name, uf: data.uf.toUpperCase() },
    });
    return { id: row.id, name: row.name, uf: row.uf, createdAt: row.createdAt };
  }

  async deleteEstado(id: string): Promise<void> {
    await this.prisma.estado.delete({ where: { id } });
  }

  // ── Cidades ────────────────────────────────────────────────────────────────

  async findAllCidades(): Promise<Cidade[]> {
    const rows = await this.prisma.cidade.findMany({
      orderBy: { name: 'asc' },
    });
    return rows.map((r) => ({ id: r.id, name: r.name, estadoId: r.estadoId, latitude: r.latitude, longitude: r.longitude, createdAt: r.createdAt }));
  }

  async findCidadesByEstado(estadoId: string): Promise<Cidade[]> {
    const rows = await this.prisma.cidade.findMany({
      where: { estadoId },
      orderBy: { name: 'asc' },
    });
    return rows.map((r) => ({ id: r.id, name: r.name, estadoId: r.estadoId, latitude: r.latitude, longitude: r.longitude, createdAt: r.createdAt }));
  }

  async findCidadeById(id: string): Promise<Cidade | null> {
    const row = await this.prisma.cidade.findUnique({ where: { id }, include: { estado: true } });
    if (!row) return null;
    return {
      id: row.id,
      name: row.name,
      estadoId: row.estadoId,
      estado: { id: row.estado.id, name: row.estado.name, uf: row.estado.uf, createdAt: row.estado.createdAt },
      latitude: row.latitude,
      longitude: row.longitude,
      createdAt: row.createdAt,
    };
  }

  async createCidade(data: CreateCidadeData): Promise<Cidade> {
    const row = await this.prisma.cidade.create({
      data: { name: data.name, estadoId: data.estadoId },
    });
    return { id: row.id, name: row.name, estadoId: row.estadoId, latitude: row.latitude, longitude: row.longitude, createdAt: row.createdAt };
  }

  async deleteCidade(id: string): Promise<void> {
    await this.prisma.cidade.delete({ where: { id } });
  }

  // ── Bairros ────────────────────────────────────────────────────────────────

  async findBairrosByCidade(cidadeId: string): Promise<Bairro[]> {
    const rows = await this.prisma.bairro.findMany({
      where: { cidadeId },
      orderBy: { name: 'asc' },
    });
    return rows.map((r) => ({ id: r.id, name: r.name, cidadeId: r.cidadeId, latitude: r.latitude, longitude: r.longitude, createdAt: r.createdAt }));
  }

  async findBairroById(id: string): Promise<Bairro | null> {
    const row = await this.prisma.bairro.findUnique({
      where: { id },
      include: { cidade: { include: { estado: true } } },
    });
    if (!row) return null;
    return {
      id: row.id,
      name: row.name,
      cidadeId: row.cidadeId,
      cidade: {
        id: row.cidade.id,
        name: row.cidade.name,
        estadoId: row.cidade.estadoId,
        estado: { id: row.cidade.estado.id, name: row.cidade.estado.name, uf: row.cidade.estado.uf, createdAt: row.cidade.estado.createdAt },
        latitude: row.cidade.latitude,
        longitude: row.cidade.longitude,
        createdAt: row.cidade.createdAt,
      },
      latitude: row.latitude,
      longitude: row.longitude,
      createdAt: row.createdAt,
    };
  }

  async createBairro(data: CreateBairroData): Promise<Bairro> {
    const row = await this.prisma.bairro.create({
      data: { name: data.name, cidadeId: data.cidadeId },
    });
    return { id: row.id, name: row.name, cidadeId: row.cidadeId, latitude: row.latitude, longitude: row.longitude, createdAt: row.createdAt };
  }

  async deleteBairro(id: string): Promise<void> {
    await this.prisma.bairro.delete({ where: { id } });
  }
}
