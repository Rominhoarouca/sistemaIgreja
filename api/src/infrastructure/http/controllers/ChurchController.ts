import type { Request, Response } from 'express';
import { z } from 'zod';
import type { UpdateChurchUseCase } from '@application/usecases/church/UpdateChurchUseCase';
import type { UploadChurchLogoUseCase } from '@application/usecases/church/UploadChurchLogoUseCase';
import type { GetChurchContextUseCase } from '@application/usecases/church/GetChurchContextUseCase';
import type { GetPublicChurchUseCase } from '@application/usecases/church/GetPublicChurchUseCase';
import { AppError } from '@shared/errors/AppError';

const updateSchema = z.object({
  name: z.string().min(2).optional(),
  address: z.string().nullable().optional(),
  // Aceita o que o usuário digita ("igreja.com.br", "www.igreja.com"): exigir
  // URL completa fazia o formulário inteiro falhar no save por causa do
  // esquema faltando. A normalização acontece abaixo.
  site: z.string().max(255).nullable().optional(),
  instagram: z.string().nullable().optional(),
  youtube: z.string().nullable().optional(),
  tiktok: z.string().nullable().optional(),
  menuColor: z.string().regex(/^#([0-9a-fA-F]{6})$/, 'Cor inválida (#RRGGBB)').optional(),
});

/** "igreja.com.br" → "https://igreja.com.br". Vazio vira null. */
function normalizeSite(site: string | null | undefined): string | null {
  const trimmed = site?.trim() ?? '';
  if (trimmed === '') return null;
  return /^https?:\/\//i.test(trimmed) ? trimmed : `https://${trimmed}`;
}

export class ChurchController {
  constructor(
    private readonly updateChurch: UpdateChurchUseCase,
    private readonly uploadLogo: UploadChurchLogoUseCase,
    private readonly getContext: GetChurchContextUseCase,
    private readonly getPublicChurch: GetPublicChurchUseCase,
  ) {}

  /** Sem autenticação: identifica a igreja na tela pública de auto-cadastro. */
  getPublicBySlug = async (req: Request, res: Response): Promise<void> => {
    const { slug } = req.params as { slug: string };
    const church = await this.getPublicChurch.execute(slug);
    res.json({ church });
  };

  /** Contexto da igreja do usuário logado (tema + plano + features). */
  getMine = async (req: Request, res: Response): Promise<void> => {
    if (!req.churchId) throw AppError.forbidden('Usuário sem igreja associada');
    const ctx = await this.getContext.execute(req.churchId);
    res.json(ctx);
  };

  update = async (req: Request, res: Response): Promise<void> => {
    if (!req.churchId) throw AppError.forbidden('Usuário sem igreja associada');
    const data = updateSchema.parse(req.body);
    const church = await this.updateChurch.execute(req.churchId, {
      ...data,
      ...(data.site !== undefined && { site: normalizeSite(data.site) }),
    });
    res.json({ church });
  };

  uploadLogoHandler = async (req: Request, res: Response): Promise<void> => {
    if (!req.churchId) throw AppError.forbidden('Usuário sem igreja associada');
    const file = req.file;
    if (!file) throw new AppError('Arquivo de logo não enviado', 400);
    const result = await this.uploadLogo.execute({
      churchId: req.churchId,
      buffer: file.buffer,
      mimeType: file.mimetype,
      size: file.size,
      originalName: file.originalname,
    });
    res.json(result);
  };
}
