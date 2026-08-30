import type { Request, Response } from 'express';
import { z } from 'zod';
import type { AssignPlanManuallyUseCase } from '@application/usecases/billing/AssignPlanManuallyUseCase';
import type { CreateCheckoutUseCase } from '@application/usecases/billing/CreateCheckoutUseCase';
import type { HandleWebhookUseCase } from '@application/usecases/billing/HandleWebhookUseCase';
import type { IPaymentGateway } from '@domain/billing/IPaymentGateway';
import { AppError } from '@shared/errors/AppError';

const tierEnum = z.enum(['FREE', 'STARTER', 'GROWTH', 'COMPLETE']);
const cycleEnum = z.enum(['MONTHLY', 'YEARLY']);

const assignSchema = z.object({
  churchId: z.string().uuid(),
  planTier: tierEnum,
  billingCycle: cycleEnum.optional(),
});

const changePlanSchema = z.object({
  planTier: tierEnum,
  billingCycle: cycleEnum.default('MONTHLY'),
  customer: z
    .object({
      name: z.string().min(2),
      email: z.string().email(),
      taxId: z.string().optional(),
    })
    .optional(),
});

const checkoutSchema = z.object({
  planTier: tierEnum,
  billingCycle: cycleEnum.default('MONTHLY'),
  customer: z.object({
    name: z.string().min(2),
    email: z.string().email(),
    taxId: z.string().optional(),
  }),
});

export class BillingController {
  constructor(
    private readonly assignManual: AssignPlanManuallyUseCase,
    private readonly createCheckout: CreateCheckoutUseCase,
    private readonly handleWebhook: HandleWebhookUseCase,
    private readonly gateway: IPaymentGateway,
  ) {}

  /** Super-admin: atribui plano manualmente a uma igreja. */
  assign = async (req: Request, res: Response): Promise<void> => {
    const data = assignSchema.parse(req.body);
    const subscription = await this.assignManual.execute(data);
    res.json({ subscription });
  };

  /** ADMIN da igreja: inicia checkout do plano no gateway. */
  checkout = async (req: Request, res: Response): Promise<void> => {
    if (!req.churchId) throw AppError.forbidden('Usuário sem igreja associada');
    const data = checkoutSchema.parse(req.body);
    const result = await this.createCheckout.execute({ churchId: req.churchId, ...data });
    res.json(result);
  };

  /**
   * ADMIN da igreja troca o próprio plano.
   *
   * Com gateway de pagamento online configurado, devolve a URL de checkout e a
   * assinatura só vira ACTIVE quando o webhook confirmar. Com o gateway manual
   * (cobrança feita fora do sistema), a troca é aplicada na hora como MANUAL —
   * é o que "manual" significa aqui. O downgrade para FREE nunca passa por
   * checkout.
   */
  changePlan = async (req: Request, res: Response): Promise<void> => {
    if (!req.churchId) throw AppError.forbidden('Usuário sem igreja associada');
    const data = changePlanSchema.parse(req.body);

    const needsCheckout =
      data.planTier !== 'FREE' && this.gateway.supportsCheckout && data.customer !== undefined;

    if (needsCheckout) {
      const result = await this.createCheckout.execute({
        churchId: req.churchId,
        planTier: data.planTier,
        billingCycle: data.billingCycle,
        customer: data.customer!,
      });
      res.json({ mode: 'checkout', checkoutUrl: result.checkoutUrl });
      return;
    }

    if (data.planTier !== 'FREE' && this.gateway.supportsCheckout) {
      throw new AppError('Dados de cobrança são obrigatórios para planos pagos', 400);
    }

    const subscription = await this.assignManual.execute({
      churchId: req.churchId,
      planTier: data.planTier,
      billingCycle: data.billingCycle,
    });
    res.json({ mode: 'assigned', subscription });
  };

  /** Público: webhook do gateway (verificado por assinatura). */
  webhook = async (req: Request, res: Response): Promise<void> => {
    const rawBody: Buffer = Buffer.isBuffer(req.body)
      ? req.body
      : Buffer.from(JSON.stringify(req.body));
    const result = await this.handleWebhook.execute(req.headers, rawBody);
    res.json(result);
  };
}
