import type { Plan } from './Plan';

export type SubscriptionStatus = 'TRIALING' | 'ACTIVE' | 'PAST_DUE' | 'CANCELED' | 'MANUAL';
export type BillingCycle = 'MONTHLY' | 'YEARLY';

export interface Subscription {
  readonly id: string;
  readonly churchId: string;
  readonly planId: string;
  readonly status: SubscriptionStatus;
  readonly billingCycle: BillingCycle;
  readonly provider: string;
  readonly externalCustomerId: string | null;
  readonly externalSubscriptionId: string | null;
  readonly currentPeriodEnd: Date | null;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export interface SubscriptionWithPlan extends Subscription {
  readonly plan: Plan;
}

export interface UpsertSubscriptionData {
  readonly churchId: string;
  readonly planId: string;
  readonly status?: SubscriptionStatus;
  readonly billingCycle?: BillingCycle;
  readonly provider?: string;
  readonly externalCustomerId?: string | null;
  readonly externalSubscriptionId?: string | null;
  readonly currentPeriodEnd?: Date | null;
}
