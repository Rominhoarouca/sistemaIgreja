import type { Plan, PlanTier, UpsertPlanData } from '../entities/Plan';

export interface IPlanRepository {
  findAll(activeOnly?: boolean): Promise<Plan[]>;
  findById(id: string): Promise<Plan | null>;
  findByTier(tier: PlanTier): Promise<Plan | null>;
  upsertByTier(data: UpsertPlanData): Promise<Plan>;
}
