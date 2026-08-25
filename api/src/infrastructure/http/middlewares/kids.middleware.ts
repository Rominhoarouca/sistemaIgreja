import type { NextFunction, Request, Response } from 'express';
import type { IKidsRepository } from '@domain/repositories/IKidsRepository';
import { AppError } from '@shared/errors/AppError';

/** Papéis que operam a salinha. RESPONSAVEL fica de fora — ele só vê os filhos. */
export function requireKidsStaff(req: Request, _res: Response, next: NextFunction): void {
  const role = req.userRole;
  if (role !== 'KIDS' && role !== 'ADMIN' && role !== 'SUPERADMIN') {
    throw AppError.forbidden('Acesso restrito à equipe do ministério infantil');
  }
  next();
}

export function requireGuardian(req: Request, _res: Response, next: NextFunction): void {
  // ADMIN também passa: precisa conseguir depurar o que o pai está vendo.
  const role = req.userRole;
  if (role !== 'RESPONSAVEL' && role !== 'ADMIN' && role !== 'SUPERADMIN') {
    throw AppError.forbidden('Acesso restrito a responsáveis');
  }
  next();
}

/**
 * Garante que o professor está vinculado à sala em questão.
 *
 * O papel `KIDS` sozinho não basta: sem esta checagem, qualquer professor da
 * igreja abriria a ficha (com dado de saúde) de qualquer criança de qualquer
 * sala. ADMIN passa direto.
 */
export function makeRequireRoomAccess(kidsRepo: IKidsRepository) {
  return (source: 'roomId' | 'sessionId' | 'checkinId', paramName = 'id') =>
    async (req: Request, _res: Response, next: NextFunction): Promise<void> => {
      if (req.userRole === 'ADMIN' || req.userRole === 'SUPERADMIN') return next();

      const raw = req.params[paramName];
      const value = Array.isArray(raw) ? raw[0] : raw;
      if (!value) throw new AppError('Identificador ausente na rota');

      let allowed = false;
      if (source === 'roomId') {
        allowed = await kidsRepo.isTeacherOfRoom(value, req.userId);
      } else if (source === 'sessionId') {
        allowed = await kidsRepo.isTeacherOfSession(value, req.userId);
      } else {
        const checkin = await kidsRepo.findCheckinById(value);
        if (!checkin) throw AppError.notFound('Check-in não encontrado');
        allowed = await kidsRepo.isTeacherOfSession(checkin.sessionId, req.userId);
      }

      if (!allowed) throw AppError.forbidden('Você não é professor desta sala');
      next();
    };
}
