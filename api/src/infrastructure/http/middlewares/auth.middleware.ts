import type { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { AppError } from '@shared/errors/AppError';
import type { UserRole } from '@domain/entities/User';
import { highestRole } from '@domain/entities/User';
import { runWithTenant } from '@shared/context/tenant-context';

interface JwtPayload {
  sub: string;
  role: UserRole;
  /** Papéis acumulados. Ausente em tokens emitidos antes do multi-papel. */
  roles?: UserRole[];
  churchId?: string | null;
}

declare global {
  // eslint-disable-next-line @typescript-eslint/no-namespace
  namespace Express {
    interface Request {
      userId: string;
      /**
       * Papel *efetivo*: o mais privilegiado entre `userRoles`. É o que as
       * regras de restrição usam ("líder só vê a própria célula"), para que
       * acumular um papel nunca tire acesso.
       */
      userRole: UserRole;
      /** Todos os papéis do usuário. Use `hasRole` para checagens de permissão. */
      userRoles: UserRole[];
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
    const roles = Array.from(new Set<UserRole>([payload.role, ...(payload.roles ?? [])]));

    if (!roles.includes('SUPERADMIN') && !payload.churchId) {
      throw AppError.unauthorized('Sessão desatualizada. Faça login novamente.');
    }

    req.userId = payload.sub;
    req.userRoles = roles;
    req.userRole = highestRole(roles);
    req.churchId = payload.churchId ?? null;

    // Ativa o contexto de tenant para todo o restante da requisição.
    // SUPERADMIN opera cross-tenant (guard do Prisma não filtra).
    runWithTenant(
      {
        churchId: payload.churchId ?? undefined,
        userId: payload.sub,
        role: req.userRole,
        crossTenant: roles.includes('SUPERADMIN'),
      },
      () => next(),
    );
  } catch (err) {
    if (err instanceof AppError) throw err;
    throw AppError.unauthorized('Token inválido ou expirado');
  }
}

/**
 * Reabre o contexto de tenant depois de um parser de corpo multipart.
 *
 * O multer processa o upload em streams do busboy, e a continuação da
 * requisição volta num contexto async diferente — o `AsyncLocalStorage` aberto
 * pelo `authMiddleware` se perde no caminho. Sem isto, o guard do Prisma deixa
 * de injetar `church_id` no que é criado (material nascia com church_id nulo e
 * sumia de todas as leituras) e de filtrar o que é lido.
 *
 * Colocar SEMPRE logo depois do `upload.single()/array()` da rota.
 */
export function restoreTenantContext(
  req: Request,
  _res: Response,
  next: NextFunction,
): void {
  runWithTenant(
    {
      churchId: req.churchId ?? undefined,
      userId: req.userId,
      role: req.userRole,
      crossTenant: hasRole(req, 'SUPERADMIN'),
    },
    () => next(),
  );
}

/** Um usuário passa se exercer QUALQUER um dos papéis informados. */
export function hasRole(req: Request, ...roles: UserRole[]): boolean {
  return roles.some((r) => req.userRoles?.includes(r));
}

export function requireSuperAdmin(req: Request, _res: Response, next: NextFunction): void {
  if (!hasRole(req, 'SUPERADMIN')) {
    throw AppError.forbidden('Acesso restrito ao super-administrador');
  }
  next();
}

export function requireAdmin(req: Request, _res: Response, next: NextFunction): void {
  // SUPERADMIN também passa nas rotas de admin de igreja.
  if (!hasRole(req, 'ADMIN', 'SUPERADMIN')) {
    throw AppError.forbidden('Acesso restrito a administradores');
  }
  next();
}

export function requireSupervisor(req: Request, _res: Response, next: NextFunction): void {
  if (!hasRole(req, 'SUPERVISOR')) {
    throw AppError.forbidden('Acesso restrito a supervisores');
  }
  next();
}

export function requireSupervisorOrAdmin(req: Request, _res: Response, next: NextFunction): void {
  if (!hasRole(req, 'ADMIN', 'SUPERADMIN', 'SUPERVISOR')) {
    throw AppError.forbidden('Acesso restrito a supervisores e administradores');
  }
  next();
}

export function requireStaff(req: Request, _res: Response, next: NextFunction): void {
  if (!hasRole(req, 'ADMIN', 'SUPERADMIN', 'SUPERVISOR', 'COORDENADOR')) {
    throw AppError.forbidden('Acesso restrito à equipe de liderança');
  }
  next();
}
