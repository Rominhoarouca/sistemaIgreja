import type {
  Subscription,
  SubscriptionWithPlan,
  UpsertSubscriptionData,
  SubscriptionStatus,
} from '../entities/Subscription';

export interface ISubscriptionRepository {
  findByChurch(churchId: string): Promise<SubscriptionWithPlan | null>;
  findByExternalSubscriptionId(externalId: string): Promise<Subscription | null>;
  upsertByChurch(data: UpsertSubscriptionData): Promise<Subscription>;
  updateStatus(churchId: string, status: SubscriptionStatus): Promise<Subscription>;
}
