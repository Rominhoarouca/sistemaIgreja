import bcrypt from 'bcryptjs';
import type { PrismaClient } from '@prisma/client';
import type { Church } from '@domain/entities/Church';
import type { User } from '@domain/entities/User';
import type { PlanTier } from '@domain/entities/Plan';
import type { SubscriptionStatus, BillingCycle } from '@domain/entities/Subscription';
import { AppError } from '@shared/errors/AppError';

interface RegisterChurchInput {
  readonly churchName: string;
  readonly slug?: string;
  readonly admin: { name: string; email: string; password: string };
  readonly planTier?: PlanTier;
  readonly billingCycle?: BillingCycle;
  /** true quando criado pelo super-admin (assinatura MANUAL). */
  readonly manual?: boolean;
}

interface RegisterChurchOutput {
  readonly church: Church;
  readonly admin: User;
}

function slugify(input: string): string {
  return input
    .toLowerCase()
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/(^-|-$)/g, '')
    .slice(0, 40);
}

/**
 * Cadastro de nova igreja (self-service público ou onboarding manual pelo
 * super-admin). Cria, em transação: Church + admin (role ADMIN) + Subscription.
 */
export class RegisterChurchUseCase {
  constructor(private readonly prisma: PrismaClient) {}

  async execute(input: RegisterChurchInput): Promise<RegisterChurchOutput> {
    const baseSlug = input.slug ? slugify(input.slug) : slugify(input.churchName);
    if (!baseSlug) throw new AppError('Nome da igreja inválido', 400);

    const email = input.admin.email.toLowerCase().trim();
    const tier: PlanTier = input.planTier ?? 'FREE';

    const plan = await this.prisma.plan.findUnique({ where: { tier } });
    if (!plan) throw AppError.notFound(`Plano ${tier} não configurado`);

    // slug único (adiciona sufixo se colidir).
    let slug = baseSlug;
    for (let i = 1; await this.prisma.church.findUnique({ where: { slug } }); i++) {
      slug = `${baseSlug}-${i}`;
      if (i > 50) throw new AppError('Não foi possível gerar identificador único', 500);
    }

    const hashed = await bcrypt.hash(input.admin.password, 12);
    const status: SubscriptionStatus = input.manual ? 'MANUAL' : 'TRIALING';

    const result = await this.prisma.$transaction(async (tx) => {
      const church = await tx.church.create({
        data: { name: input.churchName, slug },
      });

      const admin = await tx.user.create({
        data: {
          churchId: church.id,
          name: input.admin.name,
          email,
          password: hashed,
          role: 'ADMIN',
        },
      });

      await tx.subscription.create({
        data: {
          churchId: church.id,
          planId: plan.id,
          status,
          billingCycle: input.billingCycle ?? 'MONTHLY',
          provider: 'manual',
        },
      });

      return { church, admin };
    });

    const { password: _p, ...admin } = result.admin;
    return { church: result.church, admin };
  }
}
