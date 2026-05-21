import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import type { IUserRepository } from '@domain/repositories/IUserRepository';
import type { IRefreshTokenRepository } from '@domain/repositories/IRefreshTokenRepository';
import type { User } from '@domain/entities/User';
import { AppError } from '@shared/errors/AppError';

interface LoginInput {
  readonly email: string;
  readonly password: string;
}

interface LoginOutput {
  readonly user: User;
  readonly accessToken: string;
  readonly refreshToken: string;
}

export class LoginUseCase {
  constructor(
    private readonly userRepo: IUserRepository,
    private readonly refreshTokenRepo: IRefreshTokenRepository,
  ) {}

  async execute(input: LoginInput): Promise<LoginOutput> {
    const userWithPassword = await this.userRepo.findByEmail(input.email);
    if (!userWithPassword) {
      throw AppError.unauthorized('Credenciais inválidas');
    }

    const passwordMatch = await bcrypt.compare(input.password, userWithPassword.password);
    if (!passwordMatch) {
      throw AppError.unauthorized('Credenciais inválidas');
    }

    const jwtSecret = process.env['JWT_SECRET'];
    const jwtRefreshSecret = process.env['JWT_REFRESH_SECRET'];
    const expiresIn = process.env['JWT_EXPIRES_IN'] ?? '15m';
    const refreshExpiresIn = process.env['JWT_REFRESH_EXPIRES_IN'] ?? '7d';

    if (!jwtSecret || !jwtRefreshSecret) {
      throw AppError.internal('Configuração JWT ausente');
    }

    const { password: _password, ...user } = userWithPassword;

    const accessToken = jwt.sign(
      { sub: user.id, role: user.role },
      jwtSecret,
      { expiresIn: expiresIn } as jwt.SignOptions,
    );

    const rawRefreshToken = jwt.sign(
      { sub: user.id },
      jwtRefreshSecret,
      { expiresIn: refreshExpiresIn } as jwt.SignOptions,
    );

    const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
    await this.refreshTokenRepo.create({
      token: rawRefreshToken,
      userId: user.id,
      expiresAt,
    });

    return { user, accessToken, refreshToken: rawRefreshToken };
  }
}
