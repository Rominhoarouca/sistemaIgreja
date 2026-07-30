import type { Request, Response, NextFunction } from 'express';
import { AppError } from '@shared/errors/AppError';
import type { FeatureResolver } from '@application/services/FeatureResolver';
import type { FeatureKey } from '@shared/plans/features';

/**
 * Fabrica um middleware que barra (402/403) o acesso a um recurso não incluso no
 * plano da igreja. SUPERADMIN sempre passa. Deve rodar depois do authMiddleware.
 */
export function makeRequireFeature(resolver: FeatureResolver) {
  return (feature: FeatureKey) =>
    async (req: Request, _res: Response, next: NextFunction): Promise<void> => {
      if (req.userRole === 'SUPERADMIN') return next();
      if (!req.churchId) throw AppError.forbidden('Igreja não identificada');

      const allowed = await resolver.hasFeature(req.churchId, feature);
      if (!allowed) {
        throw new AppError(
          `Recurso "${feature}" não está incluído no plano atual da sua igreja`,
          402, // Payment Required
        );
      }
      next();
    };
}
