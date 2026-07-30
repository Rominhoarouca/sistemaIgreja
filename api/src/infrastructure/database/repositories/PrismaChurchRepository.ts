import type { PrismaClient } from '@prisma/client';
import type { IChurchRepository } from '@domain/repositories/IChurchRepository';
import type { Church, CreateChurchData, UpdateChurchData } from '@domain/entities/Church';

export class PrismaChurchRepository implements IChurchRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async findById(id: string): Promise<Church | null> {
    return this.prisma.church.findUnique({ where: { id } });
  }

  async findBySlug(slug: string): Promise<Church | null> {
    return this.prisma.church.findUnique({ where: { slug } });
  }

  async findAll(): Promise<Church[]> {
    return this.prisma.church.findMany({ orderBy: { createdAt: 'desc' } });
  }

  async create(data: CreateChurchData): Promise<Church> {
    return this.prisma.church.create({
      data: {
        name: data.name,
        slug: data.slug,
        address: data.address ?? null,
        ...(data.menuColor ? { menuColor: data.menuColor } : {}),
      },
    });
  }

  async update(id: string, data: UpdateChurchData): Promise<Church> {
    return this.prisma.church.update({
      where: { id },
      data: {
        ...(data.name !== undefined && { name: data.name }),
        ...(data.address !== undefined && { address: data.address }),
        ...(data.site !== undefined && { site: data.site }),
        ...(data.instagram !== undefined && { instagram: data.instagram }),
        ...(data.youtube !== undefined && { youtube: data.youtube }),
        ...(data.tiktok !== undefined && { tiktok: data.tiktok }),
        ...(data.menuColor !== undefined && { menuColor: data.menuColor }),
      },
    });
  }

  async updateLogoKey(id: string, logoKey: string): Promise<Church> {
    return this.prisma.church.update({ where: { id }, data: { logoKey } });
  }

  async setActive(id: string, isActive: boolean): Promise<Church> {
    return this.prisma.church.update({ where: { id }, data: { isActive } });
  }
}
