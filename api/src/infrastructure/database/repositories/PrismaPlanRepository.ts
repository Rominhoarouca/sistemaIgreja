import type { PrismaClient } from '@prisma/client';
import type { IPlanRepository } from '@domain/repositories/IPlanRepository';
import type { Plan, PlanTier, UpsertPlanData } from '@domain/entities/Plan';

export class PrismaPlanRepository implements IPlanRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async findAll(activeOnly = false): Promise<Plan[]> {
    return this.prisma.plan.findMany({
      where: activeOnly ? { isActive: true } : {},
      orderBy: { priceMonth: 'asc' },
    });
  }

  async findById(id: string): Promise<Plan | null> {
    return this.prisma.plan.findUnique({ where: { id } });
  }

  async findByTier(tier: PlanTier): Promise<Plan | null> {
    return this.prisma.plan.findUnique({ where: { tier } });
  }

  async upsertByTier(data: UpsertPlanData): Promise<Plan> {
    return this.prisma.plan.upsert({
      where: { tier: data.tier },
      create: {
        tier: data.tier,
        name: data.name,
        description: data.description ?? null,
        priceMonth: data.priceMonth ?? 0,
        priceYear: data.priceYear ?? 0,
        features: data.features ?? [],
        isActive: data.isActive ?? true,
      },
      update: {
        name: data.name,
        ...(data.description !== undefined && { description: data.description }),
        ...(data.priceMonth !== undefined && { priceMonth: data.priceMonth }),
        ...(data.priceYear !== undefined && { priceYear: data.priceYear }),
        ...(data.features !== undefined && { features: data.features }),
        ...(data.isActive !== undefined && { isActive: data.isActive }),
      },
    });
  }
}
