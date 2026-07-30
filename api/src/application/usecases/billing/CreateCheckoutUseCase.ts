import type { IChurchRepository } from '@domain/repositories/IChurchRepository';
import type { IPlanRepository } from '@domain/repositories/IPlanRepository';
import type { ISubscriptionRepository } from '@domain/repositories/ISubscriptionRepository';
import type { IPaymentGateway } from '@domain/billing/IPaymentGateway';
import type { BillingCycle } from '@domain/entities/Subscription';
import type { PlanTier } from '@domain/entities/Plan';
import { AppError } from '@shared/errors/AppError';

interface CheckoutInput {
  readonly churchId: string;
  readonly planTier: PlanTier;
  readonly billingCycle: BillingCycle;
  readonly customer: { name: string; email: string; taxId?: string | undefined };
}

/**
 * Inicia o checkout no gateway e registra a assinatura como PAST_DUE/TRIALING até
 * o webhook confirmar o pagamento. Retorna a URL de checkout.
 */
export class CreateCheckoutUseCase {
  constructor(
    private readonly churchRepo: IChurchRepository,
    private readonly planRepo: IPlanRepository,
    private readonly subscriptionRepo: ISubscriptionRepository,
    private readonly gateway: IPaymentGateway,
  ) {}

  async execute(input: CheckoutInput): Promise<{ checkoutUrl: string }> {
    if (!this.gateway.supportsCheckout) {
      throw new AppError(
        'Checkout online indisponível. Contate o administrador para atribuição manual do plano.',
        501,
      );
    }

    const church = await this.churchRepo.findById(input.churchId);
    if (!church) throw AppError.notFound('Igreja não encontrada');

    const plan = await this.planRepo.findByTier(input.planTier);
    if (!plan) throw AppError.notFound('Plano não encontrado');

    const publicUrl = process.env['APP_PUBLIC_URL'] ?? 'http://localhost';
    const result = await this.gateway.createCheckoutSession({
      churchId: input.churchId,
      planId: plan.id,
      billingCycle: input.billingCycle,
      successUrl: `${publicUrl}/billing/success`,
      cancelUrl: `${publicUrl}/billing/cancel`,
      customer: input.customer,
    });

    await this.subscriptionRepo.upsertByChurch({
      churchId: input.churchId,
      planId: plan.id,
      status: 'PAST_DUE', // vira ACTIVE quando o webhook confirmar
      billingCycle: input.billingCycle,
      provider: result.provider,
      externalCustomerId: result.externalCustomerId ?? null,
      externalSubscriptionId: result.externalSubscriptionId ?? null,
    });

    return { checkoutUrl: result.checkoutUrl };
  }
}
