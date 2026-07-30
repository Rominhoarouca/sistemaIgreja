import type { Request, Response } from 'express';
import { z } from 'zod';
import type { AssignPlanManuallyUseCase } from '@application/usecases/billing/AssignPlanManuallyUseCase';
import type { CreateCheckoutUseCase } from '@application/usecases/billing/CreateCheckoutUseCase';
import type { HandleWebhookUseCase } from '@application/usecases/billing/HandleWebhookUseCase';
import { AppError } from '@shared/errors/AppError';

const tierEnum = z.enum(['FREE', 'STARTER', 'GROWTH', 'COMPLETE']);
const cycleEnum = z.enum(['MONTHLY', 'YEARLY']);

const assignSchema = z.object({
  churchId: z.string().uuid(),
  planTier: tierEnum,
  billingCycle: cycleEnum.optional(),
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

  /** Público: webhook do gateway (verificado por assinatura). */
  webhook = async (req: Request, res: Response): Promise<void> => {
    const rawBody: Buffer = Buffer.isBuffer(req.body)
      ? req.body
      : Buffer.from(JSON.stringify(req.body));
    const result = await this.handleWebhook.execute(req.headers, rawBody);
    res.json(result);
  };
}
