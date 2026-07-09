import type { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { AppError } from '@shared/errors/AppError';
import type { UserRole } from '@domain/entities/User';

interface JwtPayload {
  sub: string;
  role: UserRole;
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      userId: string;
      userRole: UserRole;
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
    req.userId = payload.sub;
    req.userRole = payload.role;
    next();
  } catch {
    throw AppError.unauthorized('Token inválido ou expirado');
  }
}

export function requireAdmin(req: Request, _res: Response, next: NextFunction): void {
  if (req.userRole !== 'ADMIN') {
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
