import type { PrismaClient } from '@prisma/client';
import type { ISubscriptionRepository } from '@domain/repositories/ISubscriptionRepository';
import type {
  Subscription,
  SubscriptionWithPlan,
  UpsertSubscriptionData,
  SubscriptionStatus,
} from '@domain/entities/Subscription';

export class PrismaSubscriptionRepository implements ISubscriptionRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async findByChurch(churchId: string): Promise<SubscriptionWithPlan | null> {
    return this.prisma.subscription.findUnique({
      where: { churchId },
      include: { plan: true },
    }) as unknown as Promise<SubscriptionWithPlan | null>;
  }

  async findByExternalSubscriptionId(externalId: string): Promise<Subscription | null> {
    return this.prisma.subscription.findFirst({ where: { externalSubscriptionId: externalId } });
  }

  async upsertByChurch(data: UpsertSubscriptionData): Promise<Subscription> {
    return this.prisma.subscription.upsert({
      where: { churchId: data.churchId },
      create: {
        churchId: data.churchId,
        planId: data.planId,
        status: data.status ?? 'TRIALING',
        billingCycle: data.billingCycle ?? 'MONTHLY',
        provider: data.provider ?? 'manual',
        externalCustomerId: data.externalCustomerId ?? null,
        externalSubscriptionId: data.externalSubscriptionId ?? null,
        currentPeriodEnd: data.currentPeriodEnd ?? null,
      },
      update: {
        planId: data.planId,
        ...(data.status !== undefined && { status: data.status }),
        ...(data.billingCycle !== undefined && { billingCycle: data.billingCycle }),
        ...(data.provider !== undefined && { provider: data.provider }),
        ...(data.externalCustomerId !== undefined && { externalCustomerId: data.externalCustomerId }),
        ...(data.externalSubscriptionId !== undefined && {
          externalSubscriptionId: data.externalSubscriptionId,
        }),
        ...(data.currentPeriodEnd !== undefined && { currentPeriodEnd: data.currentPeriodEnd }),
      },
    });
  }

  async updateStatus(churchId: string, status: SubscriptionStatus): Promise<Subscription> {
    return this.prisma.subscription.update({ where: { churchId }, data: { status } });
  }
}
