import type { Request, Response, NextFunction } from 'express';
import { Prisma } from '@prisma/client';
import { AppError } from '@shared/errors/AppError';
import { ZodError } from 'zod';

export function errorMiddleware(
  err: unknown,
  _req: Request,
  res: Response,
  _next: NextFunction,
): void {
  if (err instanceof AppError) {
    res.status(err.statusCode).json({ error: { code: err.code, message: err.message } });
    return;
  }

  if (err instanceof ZodError) {
    res.status(422).json({
      error: {
        code: 'VALIDATION_ERROR',
        message: 'Dados inválidos',
        details: err.flatten().fieldErrors,
      },
    });
    return;
  }

  if (err instanceof Prisma.PrismaClientKnownRequestError) {
    if (err.code === 'P2002') {
      const target = Array.isArray(err.meta?.target)
        ? (err.meta.target as string[])
        : [];

      const isLeaderCellConflict = target.includes('leader_id') || target.includes('leaderId');

      res.status(409).json({
        error: {
          code: 'CONFLICT',
          message: isLeaderCellConflict
            ? 'Este líder já possui uma célula cadastrada'
            : 'Conflito de unicidade nos dados enviados',
        },
      });
      return;
    }
  }

  console.error('[Unhandled Error]', err);
  res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: 'Erro interno do servidor' } });
}
