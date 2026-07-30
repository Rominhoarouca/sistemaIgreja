import type {
  IPaymentGateway,
  CheckoutSessionInput,
  CheckoutSessionResult,
  WebhookEvent,
  WebhookEventType,
} from '@domain/billing/IPaymentGateway';
import { AppError } from '@shared/errors/AppError';

/**
 * Integração com Asaas (PIX/boleto/cartão recorrente, BR). Ver
 * docs/GATEWAY_PAGAMENTO.md. Skeleton funcional baseado em `fetch` (Node 20+);
 * validar contra a conta/sandbox Asaas antes de produção.
 *
 * Env: PAYMENT_API_KEY (access_token), PAYMENT_WEBHOOK_SECRET (asaas-access-token),
 * ASAAS_BASE_URL (default sandbox).
 */
export class AsaasPaymentGateway implements IPaymentGateway {
  readonly name = 'asaas';
  readonly supportsCheckout = true;

  private readonly baseUrl: string;
  private readonly apiKey: string;
  private readonly webhookSecret: string;

  constructor() {
    this.baseUrl = process.env['ASAAS_BASE_URL'] ?? 'https://sandbox.asaas.com/api/v3';
    this.apiKey = process.env['PAYMENT_API_KEY'] ?? '';
    this.webhookSecret = process.env['PAYMENT_WEBHOOK_SECRET'] ?? '';
    if (!this.apiKey) {
      throw AppError.internal('PAYMENT_API_KEY ausente para o gateway Asaas');
    }
  }

  private async api<T>(path: string, method: string, body?: unknown): Promise<T> {
    const init: RequestInit = {
      method,
      headers: {
        'Content-Type': 'application/json',
        access_token: this.apiKey,
      },
    };
    if (body) init.body = JSON.stringify(body);
    const res = await fetch(`${this.baseUrl}${path}`, init);
    if (!res.ok) {
      const text = await res.text();
      throw new AppError(`Asaas API ${res.status}: ${text}`, 502);
    }
    return (await res.json()) as T;
  }

  async createCheckoutSession(input: CheckoutSessionInput): Promise<CheckoutSessionResult> {
    // 1) cria/recupera cliente; 2) cria assinatura; 3) devolve link de pagamento.
    const customer = await this.api<{ id: string }>('/customers', 'POST', {
      name: input.customer.name,
      email: input.customer.email,
      cpfCnpj: input.customer.taxId,
    });

    const cycle = input.billingCycle === 'YEARLY' ? 'YEARLY' : 'MONTHLY';
    const sub = await this.api<{ id: string }>('/subscriptions', 'POST', {
      customer: customer.id,
      billingType: 'UNDEFINED', // cliente escolhe PIX/boleto/cartão
      cycle,
      value: 0, // valor real deve vir do plano (preencher no CreateCheckoutUseCase)
      nextDueDate: new Date().toISOString().slice(0, 10),
      externalReference: input.churchId,
    });

    const payments = await this.api<{ data: Array<{ invoiceUrl: string }> }>(
      `/subscriptions/${sub.id}/payments`,
      'GET',
    );
    const checkoutUrl = payments.data[0]?.invoiceUrl ?? input.successUrl;

    return {
      provider: this.name,
      externalSubscriptionId: sub.id,
      externalCustomerId: customer.id,
      checkoutUrl,
    };
  }

  async cancelSubscription(externalSubscriptionId: string): Promise<void> {
    await this.api(`/subscriptions/${externalSubscriptionId}`, 'DELETE');
  }

  async verifyAndParseWebhook(
    headers: Record<string, string | string[] | undefined>,
    rawBody: Buffer,
  ): Promise<WebhookEvent> {
    // Asaas autentica webhooks por um token fixo no header configurado no painel.
    const token = headers['asaas-access-token'];
    if (this.webhookSecret && token !== this.webhookSecret) {
      throw AppError.unauthorized('Webhook Asaas: token inválido');
    }

    const payload = JSON.parse(rawBody.toString('utf8')) as {
      id?: string;
      event?: string;
      subscription?: string;
      payment?: { subscription?: string; customer?: string };
    };

    const map: Record<string, WebhookEventType> = {
      PAYMENT_CONFIRMED: 'payment.confirmed',
      PAYMENT_RECEIVED: 'subscription.active',
      PAYMENT_OVERDUE: 'subscription.past_due',
      PAYMENT_DELETED: 'subscription.canceled',
      SUBSCRIPTION_DELETED: 'subscription.canceled',
    };

    return {
      type: map[payload.event ?? ''] ?? 'ignored',
      externalSubscriptionId: payload.subscription ?? payload.payment?.subscription,
      externalCustomerId: payload.payment?.customer,
      eventId: payload.id,
      raw: payload,
    };
  }
}
