import type { Request, Response } from 'express';
import { z } from 'zod';
import type { ICoordenacaoRepository } from '@domain/repositories/ICoordenacaoRepository';
import type { IUserRepository } from '@domain/repositories/IUserRepository';
import { AppError } from '@shared/errors/AppError';

const createSchema = z.object({
  name: z.string().min(1).max(100),
  color: z.string().regex(/^#[0-9a-fA-F]{6}$/, 'Cor deve ser um hex válido (#RRGGBB)'),
  coordinadorId: z.string().uuid(),
});

const updateSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  color: z.string().regex(/^#[0-9a-fA-F]{6}$/, 'Cor deve ser um hex válido (#RRGGBB)').optional(),
});

export class CoordenacaoController {
  constructor(
    private readonly coordenacaoRepo: ICoordenacaoRepository,
    private readonly userRepo: IUserRepository,
  ) {}

  listAll = async (_req: Request, res: Response): Promise<void> => {
    const coordenacoes = await this.coordenacaoRepo.findAll();
    res.json({ coordenacoes });
  };

  create = async (req: Request, res: Response): Promise<void> => {
    const body = createSchema.parse(req.body);

    const coordinador = await this.userRepo.findById(body.coordinadorId);
    if (!coordinador) throw AppError.notFound('Usuário não encontrado');
    if (coordinador.role !== 'COORDENADOR') {
      throw new AppError('O usuário informado não possui o cargo de coordenador', 422, 'INVALID_ROLE');
    }

    const existing = await this.coordenacaoRepo.findByCoordinadorId(body.coordinadorId);
    if (existing) {
      throw AppError.conflict('Este coordenador já possui uma coordenação vinculada');
    }

    const coordenacao = await this.coordenacaoRepo.create(body);
    res.status(201).json({ coordenacao });
  };

  update = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const body = updateSchema.parse(req.body);

    const existing = await this.coordenacaoRepo.findById(id);
    if (!existing) throw AppError.notFound('Coordenação não encontrada');

    const coordenacao = await this.coordenacaoRepo.update(id, body);
    res.json({ coordenacao });
  };

  remove = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const existing = await this.coordenacaoRepo.findById(id);
    if (!existing) throw AppError.notFound('Coordenação não encontrada');
    await this.coordenacaoRepo.delete(id);
    res.status(204).send();
  };
}
