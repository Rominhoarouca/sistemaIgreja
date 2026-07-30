import type { PrismaClient } from '@prisma/client';
import type { FeatureKey } from '@shared/plans/features';

interface CachedFeatures {
  readonly features: FeatureKey[];
  readonly expiresAt: number;
}

/**
 * Resolve as features ativas de uma igreja a partir da sua assinatura/plano.
 * Cache curto em memória (60s) evita ir ao banco a cada request gated.
 * Assinaturas não-ativas (CANCELED/PAST_DUE) caem para o conjunto vazio (core-only).
 */
export class FeatureResolver {
  private readonly cache = new Map<string, CachedFeatures>();
  private readonly ttlMs = 60_000;

  constructor(private readonly prisma: PrismaClient) {}

  invalidate(churchId: string): void {
    this.cache.delete(churchId);
  }

  /** Limpa todo o cache — usar quando um plano muda (afeta todas as igrejas). */
  invalidateAll(): void {
    this.cache.clear();
  }

  async getFeatures(churchId: string): Promise<FeatureKey[]> {
    const cached = this.cache.get(churchId);
    if (cached && cached.expiresAt > Date.now()) return cached.features;

    const sub = await this.prisma.subscription.findUnique({
      where: { churchId },
      include: { plan: true },
    });

    const active =
      sub != null &&
      (sub.status === 'ACTIVE' || sub.status === 'TRIALING' || sub.status === 'MANUAL');
    const features = active ? ((sub!.plan.features as FeatureKey[]) ?? []) : [];

    this.cache.set(churchId, { features, expiresAt: Date.now() + this.ttlMs });
    return features;
  }

  async hasFeature(churchId: string, feature: FeatureKey): Promise<boolean> {
    const features = await this.getFeatures(churchId);
    return features.includes(feature);
  }
}
