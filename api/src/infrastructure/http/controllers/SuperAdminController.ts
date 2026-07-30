import type { Request, Response } from 'express';
import { z } from 'zod';
import type { IChurchRepository } from '@domain/repositories/IChurchRepository';
import type { ISubscriptionRepository } from '@domain/repositories/ISubscriptionRepository';
import type { RegisterChurchUseCase } from '@application/usecases/signup/RegisterChurchUseCase';
import type { GetSaasUsageUseCase } from '@application/usecases/church/GetSaasUsageUseCase';

const createChurchSchema = z.object({
  churchName: z.string().min(2),
  slug: z.string().min(2).optional(),
  admin: z.object({
    name: z.string().min(2),
    email: z.string().email(),
    password: z.string().min(6),
  }),
  planTier: z.enum(['FREE', 'STARTER', 'GROWTH', 'COMPLETE']).optional(),
});

const setActiveSchema = z.object({ isActive: z.boolean() });

/** Painel do dono do SaaS (SUPERADMIN): gestão de igrejas/tenants. */
export class SuperAdminController {
  constructor(
    private readonly churchRepo: IChurchRepository,
    private readonly subscriptionRepo: ISubscriptionRepository,
    private readonly registerChurch: RegisterChurchUseCase,
    private readonly getSaasUsage: GetSaasUsageUseCase,
  ) {}

  listChurches = async (_req: Request, res: Response): Promise<void> => {
    const churches = await this.churchRepo.findAll();
    const withSub = await Promise.all(
      churches.map(async (c) => {
        const sub = await this.subscriptionRepo.findByChurch(c.id);
        return {
          ...c,
          plan: sub?.plan ?? null,
          subscriptionStatus: sub?.status ?? null,
        };
      }),
    );
    res.json({ churches: withSub });
  };

  createChurch = async (req: Request, res: Response): Promise<void> => {
    const data = createChurchSchema.parse(req.body);
    const result = await this.registerChurch.execute({
      churchName: data.churchName,
      ...(data.slug ? { slug: data.slug } : {}),
      admin: data.admin,
      ...(data.planTier ? { planTier: data.planTier } : {}),
      manual: true,
    });
    res.status(201).json(result);
  };

  setActive = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const { isActive } = setActiveSchema.parse(req.body);
    const church = await this.churchRepo.setActive(id, isActive);
    res.json({ church });
  };

  usage = async (_req: Request, res: Response): Promise<void> => {
    const result = await this.getSaasUsage.execute();
    res.json(result);
  };
}
