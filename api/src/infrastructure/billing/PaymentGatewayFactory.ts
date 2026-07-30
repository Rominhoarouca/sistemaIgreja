import type { IPaymentGateway } from '@domain/billing/IPaymentGateway';
import { ManualPaymentGateway } from './ManualPaymentGateway';
import { AsaasPaymentGateway } from './AsaasPaymentGateway';
import { logger } from '@shared/logger/logger';

/**
 * Seleciona o gateway conforme PAYMENT_PROVIDER. Default: manual.
 * Adicionar novos providers (mercadopago, stripe) aqui.
 */
export function createPaymentGateway(): IPaymentGateway {
  const provider = (process.env['PAYMENT_PROVIDER'] ?? 'manual').toLowerCase();
  try {
    switch (provider) {
      case 'asaas':
        return new AsaasPaymentGateway();
      case 'manual':
      default:
        return new ManualPaymentGateway();
    }
  } catch (err) {
    logger.error(`[billing] Falha ao inicializar gateway "${provider}", usando manual`, err as Error);
    return new ManualPaymentGateway();
  }
}
