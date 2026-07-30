import type { Request, Response } from 'express';
import { z } from 'zod';
import type { IPlanRepository } from '@domain/repositories/IPlanRepository';
import type { FeatureResolver } from '@application/services/FeatureResolver';
import { FEATURE_CATALOG, ALL_FEATURES } from '@shared/plans/features';

const upsertSchema = z.object({
  tier: z.enum(['FREE', 'STARTER', 'GROWTH', 'COMPLETE']),
  name: z.string().min(2),
  description: z.string().nullable().optional(),
  priceMonth: z.number().int().min(0).optional(),
  priceYear: z.number().int().min(0).optional(),
  features: z.array(z.enum(ALL_FEATURES as [string, ...string[]])).optional(),
  isActive: z.boolean().optional(),
});

export class PlanController {
  constructor(
    private readonly planRepo: IPlanRepository,
    private readonly featureResolver: FeatureResolver,
  ) {}

  /** Público (autenticado): lista planos ativos para tela de assinatura. */
  listActive = async (_req: Request, res: Response): Promise<void> => {
    const plans = await this.planRepo.findAll(true);
    res.json({ plans });
  };

  /** Público SEM autenticação: planos ativos + catálogo, para a landing page. */
  listPublic = async (_req: Request, res: Response): Promise<void> => {
    const plans = await this.planRepo.findAll(true);
    res.json({ plans, catalog: FEATURE_CATALOG });
  };

  /** Catálogo de features com rótulos (editor de planos do super-admin). */
  catalog = async (_req: Request, res: Response): Promise<void> => {
    res.json({ catalog: FEATURE_CATALOG });
  };

  /** Super-admin: lista todos os planos (inclui inativos). */
  listAll = async (_req: Request, res: Response): Promise<void> => {
    const plans = await this.planRepo.findAll(false);
    res.json({ plans });
  };

  /** Super-admin: cria/atualiza plano por tier. */
  upsert = async (req: Request, res: Response): Promise<void> => {
    const data = upsertSchema.parse(req.body);
    const plan = await this.planRepo.upsertByTier(data);
    // Mudança de features do plano afeta todas as igrejas nele → limpa cache.
    this.featureResolver.invalidateAll();
    res.json({ plan });
  };
}
