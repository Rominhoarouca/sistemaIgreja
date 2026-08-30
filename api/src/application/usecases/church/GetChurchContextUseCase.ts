import type { IChurchRepository } from '@domain/repositories/IChurchRepository';
import type { ISubscriptionRepository } from '@domain/repositories/ISubscriptionRepository';
import type { MinioService } from '@infrastructure/storage/MinioService';
import type { Church } from '@domain/entities/Church';
import type { Plan } from '@domain/entities/Plan';
import type { SubscriptionStatus } from '@domain/entities/Subscription';
import { AppError } from '@shared/errors/AppError';

export interface ChurchContext {
  readonly church: Church & { logoUrl: string | null };
  readonly plan: Plan | null;
  readonly subscriptionStatus: SubscriptionStatus | null;
  readonly features: string[];
}

/**
 * Contexto multi-tenant do app: dados da igreja (com URL da logo), plano ativo e
 * lista de features. Consumido pelo Flutter no bootstrap para tema + gating.
 */
export class GetChurchContextUseCase {
  constructor(
    private readonly churchRepo: IChurchRepository,
    private readonly subscriptionRepo: ISubscriptionRepository,
    private readonly minio: MinioService,
  ) {}

  async execute(churchId: string): Promise<ChurchContext> {
    const church = await this.churchRepo.findById(churchId);
    if (!church) throw AppError.notFound('Igreja não encontrada');

    const sub = await this.subscriptionRepo.findByChurch(churchId);
    const active =
      sub != null &&
      (sub.status === 'ACTIVE' || sub.status === 'TRIALING' || sub.status === 'MANUAL');

    let logoUrl: string | null = null;
    if (church.logoKey) {
      try {
        logoUrl = await this.minio.presignedDownloadUrl(church.logoKey, 3600, churchId);
      } catch {
        logoUrl = null;
      }
    }

    return {
      church: { ...church, logoUrl },
      plan: sub?.plan ?? null,
      subscriptionStatus: sub?.status ?? null,
      features: active ? sub!.plan.features : [],
    };
  }
}
