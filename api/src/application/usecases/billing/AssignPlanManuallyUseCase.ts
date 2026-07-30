import type { IChurchRepository } from '@domain/repositories/IChurchRepository';
import type { IPlanRepository } from '@domain/repositories/IPlanRepository';
import type { ISubscriptionRepository } from '@domain/repositories/ISubscriptionRepository';
import type { FeatureResolver } from '@application/services/FeatureResolver';
import type { Subscription, BillingCycle } from '@domain/entities/Subscription';
import type { PlanTier } from '@domain/entities/Plan';
import { AppError } from '@shared/errors/AppError';

interface AssignInput {
  readonly churchId: string;
  readonly planTier: PlanTier;
  readonly billingCycle?: BillingCycle | undefined;
}

/**
 * Atribuição manual de plano (super-admin). Não passa por gateway; marca a
 * assinatura como MANUAL e libera as features do plano imediatamente.
 */
export class AssignPlanManuallyUseCase {
  constructor(
    private readonly churchRepo: IChurchRepository,
    private readonly planRepo: IPlanRepository,
    private readonly subscriptionRepo: ISubscriptionRepository,
    private readonly featureResolver: FeatureResolver,
  ) {}

  async execute(input: AssignInput): Promise<Subscription> {
    const church = await this.churchRepo.findById(input.churchId);
    if (!church) throw AppError.notFound('Igreja não encontrada');

    const plan = await this.planRepo.findByTier(input.planTier);
    if (!plan) throw AppError.notFound('Plano não encontrado');

    const sub = await this.subscriptionRepo.upsertByChurch({
      churchId: input.churchId,
      planId: plan.id,
      status: 'MANUAL',
      billingCycle: input.billingCycle ?? 'MONTHLY',
      provider: 'manual',
    });

    this.featureResolver.invalidate(input.churchId);
    return sub;
  }
}
