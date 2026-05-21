import type { RefreshToken } from '../entities/RefreshToken';

export interface IRefreshTokenRepository {
  create(data: { token: string; userId: string; expiresAt: Date }): Promise<RefreshToken>;
  findByToken(token: string): Promise<RefreshToken | null>;
  deleteByToken(token: string): Promise<void>;
  deleteByUserId(userId: string): Promise<void>;
}
