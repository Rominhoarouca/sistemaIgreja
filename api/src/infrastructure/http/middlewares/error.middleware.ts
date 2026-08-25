import type { Request, Response, NextFunction } from 'express';
import { Prisma } from '@prisma/client';
import { AppError } from '@shared/errors/AppError';
import { ZodError } from 'zod';
import { logger } from '@shared/logger/logger';

const isVerbose = () =>
  ['verbose', 'debug', 'silly'].includes(
    (process.env['LOG_LEVEL'] ?? '').toLowerCase(),
  );

export function errorMiddleware(
  err: unknown,
  req: Request,
  res: Response,
  _next: NextFunction,
): void {
  // Always log errors; include stacktrace on verbose
  if (isVerbose()) {
    logger.error(`[Error] ${req.method} ${req.originalUrl}`, {
      error: err instanceof Error ? err.message : String(err),
      stack: err instanceof Error ? err.stack : undefined,
      reqBody: req.body as unknown,
    });
  }

  if (err instanceof AppError) {
    res.status(err.statusCode).json({
      error: {
        code: err.code,
        message: err.message,
        ...(err.details ? { details: err.details } : {}),
      },
    });
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

  if (!isVerbose()) {
    console.error('[Unhandled Error]', err);
  }
  res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: 'Erro interno do servidor' } });
}
