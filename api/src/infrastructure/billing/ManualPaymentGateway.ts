import type {
  IPaymentGateway,
  CheckoutSessionInput,
  CheckoutSessionResult,
  WebhookEvent,
} from '@domain/billing/IPaymentGateway';
import { AppError } from '@shared/errors/AppError';

/**
 * Gateway "manual": não há cobrança online. O super-admin atribui o plano
 * diretamente (AssignPlanManuallyUseCase). Usado quando PAYMENT_PROVIDER=manual.
 */
export class ManualPaymentGateway implements IPaymentGateway {
  readonly name = 'manual';
  readonly supportsCheckout = false;

  async createCheckoutSession(_input: CheckoutSessionInput): Promise<CheckoutSessionResult> {
    throw new AppError(
      'Checkout online não está habilitado. Configure um gateway de pagamento (PAYMENT_PROVIDER).',
      501,
    );
  }

  async cancelSubscription(_externalSubscriptionId: string): Promise<void> {
    // Nada a fazer no modo manual.
  }

  async verifyAndParseWebhook(): Promise<WebhookEvent> {
    return { type: 'ignored', raw: null };
  }
}
