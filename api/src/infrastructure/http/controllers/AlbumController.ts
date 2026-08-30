import type { Request, Response } from 'express';
import { z } from 'zod';
import type { GetAlbumUseCase } from '@application/usecases/album/GetAlbumUseCase';
import type { AlbumScope } from '@domain/repositories/IAlbumRepository';
import { AppError } from '@shared/errors/AppError';
import { hasRole } from '../middlewares/auth.middleware';

const daysQuerySchema = z.object({
  limit: z.coerce.number().int().min(1).max(120).default(30),
});

const dateParamSchema = z.object({
  date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Data deve ser YYYY-MM-DD'),
});

export class AlbumController {
  constructor(private readonly getAlbum: GetAlbumUseCase) {}

  /**
   * Recorte de quem está olhando.
   *
   * A ordem importa: quem acumula admin e supervisor vê tudo, não só as
   * próprias células — o papel mais amplo ganha.
   */
  private scopeOf(req: Request): AlbumScope {
    if (hasRole(req, 'ADMIN', 'SUPERADMIN')) return { kind: 'ALL' };
    if (hasRole(req, 'COORDENADOR')) {
      return { kind: 'COORDENADOR', userId: req.userId };
    }
    if (hasRole(req, 'SUPERVISOR')) {
      return { kind: 'SUPERVISOR', userId: req.userId };
    }
    throw AppError.forbidden('Álbum restrito a supervisores, coordenadores e administradores');
  }

  listDays = async (req: Request, res: Response): Promise<void> => {
    const { limit } = daysQuerySchema.parse(req.query);
    const days = await this.getAlbum.listDays(this.scopeOf(req), limit);
    res.json({ days });
  };

  getDay = async (req: Request, res: Response): Promise<void> => {
    const { date } = dateParamSchema.parse(req.params);
    // `date` puro em UTC: `meeting_date` é `date` no banco e um Date local
    // deslocaria o dia em fuso negativo.
    const album = await this.getAlbum.getDay(
      this.scopeOf(req),
      new Date(`${date}T00:00:00.000Z`),
    );
    res.json({ album });
  };
}
