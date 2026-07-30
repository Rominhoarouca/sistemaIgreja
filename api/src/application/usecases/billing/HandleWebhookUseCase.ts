import type { ISubscriptionRepository } from '@domain/repositories/ISubscriptionRepository';
import type { IPaymentGateway } from '@domain/billing/IPaymentGateway';
import type { FeatureResolver } from '@application/services/FeatureResolver';
import type { SubscriptionStatus } from '@domain/entities/Subscription';
import { logger } from '@shared/logger/logger';

/**
 * Processa webhooks do gateway. Só o webhook (verificado/assinado) muda o status
 * da assinatura. Idempotente por eventId (guarda em memória; para produção,
 * persistir em tabela de eventos processados).
 */
export class HandleWebhookUseCase {
  private readonly processed = new Set<string>();

  constructor(
    private readonly subscriptionRepo: ISubscriptionRepository,
    private readonly gateway: IPaymentGateway,
    private readonly featureResolver: FeatureResolver,
  ) {}

  async execute(
    headers: Record<string, string | string[] | undefined>,
    rawBody: Buffer,
  ): Promise<{ handled: boolean }> {
    const event = await this.gateway.verifyAndParseWebhook(headers, rawBody);

    if (event.type === 'ignored') return { handled: false };
    if (event.eventId && this.processed.has(event.eventId)) return { handled: true };

    if (!event.externalSubscriptionId) {
      logger.warn('[billing] webhook sem externalSubscriptionId', event as unknown as object);
      return { handled: false };
    }

    const sub = await this.subscriptionRepo.findByExternalSubscriptionId(
      event.externalSubscriptionId,
    );
    if (!sub) {
      logger.warn(`[billing] assinatura não encontrada: ${event.externalSubscriptionId}`);
      return { handled: false };
    }

    const statusMap: Record<string, SubscriptionStatus> = {
      'subscription.active': 'ACTIVE',
      'payment.confirmed': 'ACTIVE',
      'subscription.past_due': 'PAST_DUE',
      'payment.failed': 'PAST_DUE',
      'subscription.canceled': 'CANCELED',
    };
    const newStatus = statusMap[event.type];
    if (newStatus) {
      await this.subscriptionRepo.updateStatus(sub.churchId, newStatus);
      this.featureResolver.invalidate(sub.churchId);
    }

    if (event.eventId) this.processed.add(event.eventId);
    return { handled: true };
  }
}
