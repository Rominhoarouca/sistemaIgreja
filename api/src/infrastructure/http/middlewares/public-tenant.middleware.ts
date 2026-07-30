import type { NextFunction, Request, Response } from 'express';
import type { IChurchRepository } from '@domain/repositories/IChurchRepository';
import { runWithTenant } from '@shared/context/tenant-context';
import { AppError } from '@shared/errors/AppError';

/**
 * Resolve a igreja em rotas públicas (sem login) a partir do slug enviado em
 * `?churchSlug=` ou no corpo da requisição, e ativa o contexto de tenant.
 *
 * Sem isso essas rotas rodam sem tenant e o guard do Prisma não tem o que
 * filtrar: leituras devolvem dados de todas as igrejas e escritas nascem com
 * `church_id` nulo — invisíveis para a própria igreja.
 *
 * `required: true` recusa a requisição quando o slug não vem. É o certo para
 * escrita: sem igreja identificada não há onde gravar o registro.
 */
export function makePublicTenantMiddleware(
  churchRepo: IChurchRepository,
  options: { required: boolean },
) {
  return async function publicTenant(
    req: Request,
    _res: Response,
    next: NextFunction,
  ): Promise<void> {
    const body = req.body as Record<string, unknown> | undefined;
    const raw = req.query['churchSlug'] ?? body?.['churchSlug'];
    const slug = typeof raw === 'string' ? raw.trim().toLowerCase() : '';

    if (!slug) {
      if (options.required) {
        throw new AppError(
          'Igreja não identificada. Use o link ou QR Code da sua igreja.',
          400,
          'CHURCH_REQUIRED',
        );
      }
      next();
      return;
    }

    const church = await churchRepo.findBySlug(slug);
    if (!church || !church.isActive) {
      throw AppError.notFound('Igreja não encontrada');
    }

    req.churchId = church.id;
    runWithTenant({ churchId: church.id }, () => next());
  };
}
