export type PlanTier = 'FREE' | 'STARTER' | 'GROWTH' | 'COMPLETE';

export interface Plan {
  readonly id: string;
  readonly tier: PlanTier;
  readonly name: string;
  readonly description: string | null;
  readonly priceMonth: number; // centavos
  readonly priceYear: number; // centavos
  readonly features: string[];
  readonly isActive: boolean;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export interface UpsertPlanData {
  readonly tier: PlanTier;
  readonly name: string;
  readonly description?: string | null | undefined;
  readonly priceMonth?: number | undefined;
  readonly priceYear?: number | undefined;
  readonly features?: string[] | undefined;
  readonly isActive?: boolean | undefined;
}
