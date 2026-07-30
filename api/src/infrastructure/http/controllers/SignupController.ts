import type { Request, Response } from 'express';
import { z } from 'zod';
import type { RegisterChurchUseCase } from '@application/usecases/signup/RegisterChurchUseCase';
import type { LoginUseCase } from '@application/usecases/auth/LoginUseCase';

const signupSchema = z.object({
  churchName: z.string().min(2),
  slug: z.string().min(2).optional(),
  admin: z.object({
    name: z.string().min(2),
    email: z.string().email(),
    password: z.string().min(6),
  }),
  planTier: z.enum(['FREE', 'STARTER', 'GROWTH', 'COMPLETE']).optional(),
  billingCycle: z.enum(['MONTHLY', 'YEARLY']).optional(),
});

/** Cadastro self-service público de uma nova igreja + auto-login. */
export class SignupController {
  constructor(
    private readonly registerChurch: RegisterChurchUseCase,
    private readonly loginUseCase: LoginUseCase,
  ) {}

  signup = async (req: Request, res: Response): Promise<void> => {
    const data = signupSchema.parse(req.body);
    const { church, admin } = await this.registerChurch.execute({
      churchName: data.churchName,
      ...(data.slug ? { slug: data.slug } : {}),
      admin: data.admin,
      ...(data.planTier ? { planTier: data.planTier } : {}),
      ...(data.billingCycle ? { billingCycle: data.billingCycle } : {}),
      manual: false,
    });

    const auth = await this.loginUseCase.execute({
      email: data.admin.email,
      password: data.admin.password,
    });

    res.status(201).json({
      church,
      user: admin,
      accessToken: auth.accessToken,
      refreshToken: auth.refreshToken,
    });
  };
}
