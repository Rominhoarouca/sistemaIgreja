import type { Request, Response } from 'express';
import { z } from 'zod';
import type { LoginUseCase } from '@application/usecases/auth/LoginUseCase';
import type { RefreshTokenUseCase } from '@application/usecases/auth/RefreshTokenUseCase';
import type { RegisterUserUseCase } from '@application/usecases/auth/RegisterUserUseCase';
import type { IRefreshTokenRepository } from '@domain/repositories/IRefreshTokenRepository';
import type { IUserRepository } from '@domain/repositories/IUserRepository';
import { AppError } from '@shared/errors/AppError';

const loginSchema = z.object({
  email: z.string().email('E-mail inválido'),
  password: z.string().min(6, 'Senha deve ter no mínimo 6 caracteres'),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(1),
});

const registerSchema = z.object({
  name: z.string().min(2),
  email: z.string().email('E-mail inválido'),
  password: z.string().min(6, 'Senha deve ter no mínimo 6 caracteres'),
  role: z.enum(['ADMIN', 'LIDER']),
});

export class AuthController {
  constructor(
    private readonly loginUseCase: LoginUseCase,
    private readonly refreshTokenUseCase: RefreshTokenUseCase,
    private readonly registerUserUseCase: RegisterUserUseCase,
    private readonly refreshTokenRepo: IRefreshTokenRepository,
    private readonly userRepo: IUserRepository,
  ) {}

  login = async (req: Request, res: Response): Promise<void> => {
    const body = loginSchema.parse(req.body);
    const result = await this.loginUseCase.execute(body);
    res.json({
      user: result.user,
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    });
  };

  refresh = async (req: Request, res: Response): Promise<void> => {
    const { refreshToken } = refreshSchema.parse(req.body);
    const result = await this.refreshTokenUseCase.execute(refreshToken);
    res.json({
      user: result.user,
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
    });
  };

  register = async (req: Request, res: Response): Promise<void> => {
    const data = registerSchema.parse(req.body);
    const user = await this.registerUserUseCase.execute(data);
    res.status(201).json({ user });
  };

  logout = async (req: Request, res: Response): Promise<void> => {
    const { refreshToken } = refreshSchema.parse(req.body);
    await this.refreshTokenRepo.deleteByToken(refreshToken);
    res.status(204).send();
  };

  me = async (req: Request, res: Response): Promise<void> => {
    const user = await this.userRepo.findById(req.userId);
    if (!user) throw AppError.notFound('Usuário não encontrado');
    res.json({ user });
  };
}
