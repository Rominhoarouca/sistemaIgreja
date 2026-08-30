import jwt from 'jsonwebtoken';
import type { IUserRepository } from '@domain/repositories/IUserRepository';
import type { IRefreshTokenRepository } from '@domain/repositories/IRefreshTokenRepository';
import type { User } from '@domain/entities/User';
import { effectiveRoles } from '@domain/entities/User';
import { AppError } from '@shared/errors/AppError';

interface RefreshOutput {
  readonly user: User;
  readonly accessToken: string;
  readonly refreshToken: string;
}

export class RefreshTokenUseCase {
  constructor(
    private readonly userRepo: IUserRepository,
    private readonly refreshTokenRepo: IRefreshTokenRepository,
  ) {}

  async execute(token: string): Promise<RefreshOutput> {
    const jwtRefreshSecret = process.env['JWT_REFRESH_SECRET'];
    const jwtSecret = process.env['JWT_SECRET'];
    const expiresIn = process.env['JWT_EXPIRES_IN'] ?? '15m';
    const refreshExpiresIn = process.env['JWT_REFRESH_EXPIRES_IN'] ?? '7d';

    if (!jwtSecret || !jwtRefreshSecret) {
      throw AppError.internal('Configuração JWT ausente');
    }

    const stored = await this.refreshTokenRepo.findByToken(token);
    if (!stored || stored.expiresAt < new Date()) {
      throw AppError.unauthorized('Refresh token inválido ou expirado');
    }

    try {
      jwt.verify(token, jwtRefreshSecret);
    } catch {
      throw AppError.unauthorized('Refresh token inválido');
    }

    const user = await this.userRepo.findById(stored.userId);
    if (!user) throw AppError.unauthorized('Usuário não encontrado');

    await this.refreshTokenRepo.deleteByToken(token);

    const accessToken = jwt.sign(
      { sub: user.id, role: user.role, roles: effectiveRoles(user), churchId: user.churchId },
      jwtSecret,
      { expiresIn } as jwt.SignOptions,
    );

    const newRefreshToken = jwt.sign(
      { sub: user.id },
      jwtRefreshSecret,
      { expiresIn: refreshExpiresIn } as jwt.SignOptions,
    );

    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    await this.refreshTokenRepo.create({ token: newRefreshToken, userId: user.id, expiresAt });

    return { user, accessToken, refreshToken: newRefreshToken };
  }
}
