import type { Request, Response } from 'express';
import type { PrismaClient } from '@prisma/client';
import { z } from 'zod';

const registerSchema = z.object({
  token: z.string().min(20).max(4096),
  platform: z.enum(['ios', 'android', 'web']),
  appVersion: z.string().max(40).optional(),
  /// Aceita alerta crítico (emergência) fora do horário/modo silencioso.
  criticalOptIn: z.boolean().optional(),
});

/**
 * Registro do aparelho para push.
 *
 * O token do FCM muda: reinstalação, restauração de backup, limpeza de dados.
 * Por isso o registro é idempotente por token e o app o reenvia a cada
 * inicialização e a cada `onTokenRefresh`.
 */
export class DeviceController {
  constructor(private readonly prisma: PrismaClient) {}

  register = async (req: Request, res: Response): Promise<void> => {
    const body = registerSchema.parse(req.body);

    // O mesmo token pode migrar de usuário: aparelho compartilhado, ou logout
    // e login com outra conta. O `upsert` por token reatribui o dono em vez de
    // deixar push da mãe chegando para quem entrou depois.
    const device = await this.prisma.deviceToken.upsert({
      where: { token: body.token },
      create: {
        token: body.token,
        userId: req.userId,
        churchId: req.churchId ?? null,
        platform: body.platform,
        appVersion: body.appVersion ?? null,
        criticalOptIn: body.criticalOptIn ?? false,
      },
      update: {
        userId: req.userId,
        churchId: req.churchId ?? null,
        platform: body.platform,
        appVersion: body.appVersion ?? null,
        ...(body.criticalOptIn !== undefined ? { criticalOptIn: body.criticalOptIn } : {}),
        lastSeenAt: new Date(),
      },
      select: { id: true, platform: true, criticalOptIn: true },
    });

    res.status(201).json({ device });
  };

  /** Baixa do aparelho no logout: sem isto o push continua chegando. */
  unregister = async (req: Request, res: Response): Promise<void> => {
    const { token } = z.object({ token: z.string().min(20) }).parse(req.body);
    await this.prisma.deviceToken.deleteMany({
      where: { token, userId: req.userId },
    });
    res.status(204).send();
  };
}
