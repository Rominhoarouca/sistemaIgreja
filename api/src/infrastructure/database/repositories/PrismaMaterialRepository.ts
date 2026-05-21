import type { PrismaClient } from '@prisma/client';
import type { IMaterialRepository } from '@domain/repositories/IMaterialRepository';
import type { Material, CreateMaterialData } from '@domain/entities/Material';

export class PrismaMaterialRepository implements IMaterialRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async findById(id: string): Promise<Material | null> {
    return this.prisma.material.findUnique({ where: { id } });
  }

  async findByCell(cellId: string): Promise<Material[]> {
    return this.prisma.material.findMany({
      where: { cellId },
      orderBy: { uploadedAt: 'desc' },
    });
  }

  async findAll(): Promise<Material[]> {
    return this.prisma.material.findMany({
      orderBy: { uploadedAt: 'desc' },
    });
  }

  async create(data: CreateMaterialData): Promise<Material> {
    return this.prisma.material.create({
      data: {
        cellId: data.cellId,
        title: data.title,
        description: data.description ?? null,
        url: data.url,
        fileType: data.fileType,
        sizeBytes: data.sizeBytes,
        uploadedById: data.uploadedById,
      },
    });
  }

  async delete(id: string): Promise<void> {
    await this.prisma.material.delete({ where: { id } });
  }
}
