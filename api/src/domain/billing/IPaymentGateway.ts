import type { BillingCycle } from '@domain/entities/Subscription';

export interface CheckoutSessionInput {
  readonly churchId: string;
  readonly planId: string;
  readonly billingCycle: BillingCycle;
  readonly successUrl: string;
  readonly cancelUrl: string;
  readonly customer: { name: string; email: string; taxId?: string | undefined };
}

export interface CheckoutSessionResult {
  readonly provider: string;
  readonly externalSubscriptionId?: string | undefined;
  readonly externalCustomerId?: string | undefined;
  readonly checkoutUrl: string;
}

export type WebhookEventType =
  | 'subscription.active'
  | 'subscription.past_due'
  | 'subscription.canceled'
  | 'payment.confirmed'
  | 'payment.failed'
  | 'ignored';

export interface WebhookEvent {
  readonly type: WebhookEventType;
  readonly externalSubscriptionId?: string | undefined;
  readonly externalCustomerId?: string | undefined;
  readonly eventId?: string | undefined;
  readonly raw: unknown;
}

/**
 * Abstração de gateway de pagamento. Implementações concretas: manual (sem
 * cobrança), Asaas, Mercado Pago, Stripe. Ver docs/GATEWAY_PAGAMENTO.md.
 */
export interface IPaymentGateway {
  readonly name: string;
  /** Se false, o provider não faz checkout online (ex.: 'manual'). */
  readonly supportsCheckout: boolean;
  createCheckoutSession(input: CheckoutSessionInput): Promise<CheckoutSessionResult>;
  cancelSubscription(externalSubscriptionId: string): Promise<void>;
  verifyAndParseWebhook(
    headers: Record<string, string | string[] | undefined>,
    rawBody: Buffer,
  ): Promise<WebhookEvent>;
}
