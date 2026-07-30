import type { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { AppError } from '@shared/errors/AppError';
import type { UserRole } from '@domain/entities/User';
import { runWithTenant } from '@shared/context/tenant-context';

interface JwtPayload {
  sub: string;
  role: UserRole;
  churchId?: string | null;
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      userId: string;
      userRole: UserRole;
      churchId: string | null;
    }
  }
}

export function authMiddleware(req: Request, _res: Response, next: NextFunction): void {
  const authHeader = req.headers['authorization'];
  if (!authHeader?.startsWith('Bearer ')) {
    throw AppError.unauthorized('Token não fornecido');
  }

  const token = authHeader.split(' ')[1];
  if (!token) throw AppError.unauthorized('Token inválido');

  const secret = process.env['JWT_SECRET'];
  if (!secret) throw AppError.internal('Configuração JWT ausente');

  try {
    const payload = jwt.verify(token, secret) as JwtPayload;

    // Todo usuário não-SUPERADMIN precisa de churchId no token. Um token
    // emitido antes de uma migration/backfill de tenant (ou de qualquer
    // alteração no churchId do usuário) pode ficar "órfão" — sem essa
    // checagem, o guard do Prisma simplesmente não filtra nem preenche
    // churchId, e dados cross-tenant/sem-igreja são criados/lidos em
    // silêncio. Força relogin em vez disso.
    if (payload.role !== 'SUPERADMIN' && !payload.churchId) {
      throw AppError.unauthorized('Sessão desatualizada. Faça login novamente.');
    }

    req.userId = payload.sub;
    req.userRole = payload.role;
    req.churchId = payload.churchId ?? null;

    // Ativa o contexto de tenant para todo o restante da requisição.
    // SUPERADMIN opera cross-tenant (guard do Prisma não filtra).
    runWithTenant(
      {
        churchId: payload.churchId ?? undefined,
        userId: payload.sub,
        role: payload.role,
        crossTenant: payload.role === 'SUPERADMIN',
      },
      () => next(),
    );
  } catch (err) {
    if (err instanceof AppError) throw err;
    throw AppError.unauthorized('Token inválido ou expirado');
  }
}

export function requireSuperAdmin(req: Request, _res: Response, next: NextFunction): void {
  if (req.userRole !== 'SUPERADMIN') {
    throw AppError.forbidden('Acesso restrito ao super-administrador');
  }
  next();
}

export function requireAdmin(req: Request, _res: Response, next: NextFunction): void {
  // SUPERADMIN também passa nas rotas de admin de igreja.
  if (req.userRole !== 'ADMIN' && req.userRole !== 'SUPERADMIN') {
    throw AppError.forbidden('Acesso restrito a administradores');
  }
  next();
}

export function requireSupervisor(req: Request, _res: Response, next: NextFunction): void {
  if (req.userRole !== 'SUPERVISOR') {
    throw AppError.forbidden('Acesso restrito a supervisores');
  }
  next();
}

export function requireSupervisorOrAdmin(req: Request, _res: Response, next: NextFunction): void {
  if (req.userRole !== 'ADMIN' && req.userRole !== 'SUPERVISOR') {
    throw AppError.forbidden('Acesso restrito a supervisores e administradores');
  }
  next();
}

export function requireStaff(req: Request, _res: Response, next: NextFunction): void {
  if (req.userRole !== 'ADMIN' && req.userRole !== 'SUPERVISOR' && req.userRole !== 'COORDENADOR') {
    throw AppError.forbidden('Acesso restrito à equipe de liderança');
  }
  next();
}
