import type { Request, Response } from 'express';
import { z } from 'zod';
import type { ILocationRepository } from '@domain/repositories/ILocationRepository';
import { AppError } from '@shared/errors/AppError';

const createEstadoSchema = z.object({
  name: z.string().min(2),
  uf: z.string().length(2),
});

const createCidadeSchema = z.object({
  name: z.string().min(2),
  estadoId: z.string().uuid(),
});

const createBairroSchema = z.object({
  name: z.string().min(2),
  cidadeId: z.string().uuid(),
});

export class LocationController {
  constructor(private readonly locationRepo: ILocationRepository) {}

  // ── Estados ────────────────────────────────────────────────────────────────

  listEstados = async (_req: Request, res: Response): Promise<void> => {
    const estados = await this.locationRepo.findAllEstados();
    res.json({ estados });
  };

  createEstado = async (req: Request, res: Response): Promise<void> => {
    const data = createEstadoSchema.parse(req.body);
    const estado = await this.locationRepo.createEstado(data);
    res.status(201).json({ estado });
  };

  deleteEstado = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const exists = await this.locationRepo.findEstadoById(id);
    if (!exists) throw AppError.notFound('Estado não encontrado');
    await this.locationRepo.deleteEstado(id);
    res.status(204).send();
  };

  // ── Cidades ────────────────────────────────────────────────────────────────

  listCidadesByEstado = async (req: Request, res: Response): Promise<void> => {
    const { estadoId } = req.params as { estadoId: string };
    const estado = await this.locationRepo.findEstadoById(estadoId);
    if (!estado) throw AppError.notFound('Estado não encontrado');
    const cidades = await this.locationRepo.findCidadesByEstado(estadoId);
    res.json({ cidades });
  };

  createCidade = async (req: Request, res: Response): Promise<void> => {
    const data = createCidadeSchema.parse(req.body);
    const estado = await this.locationRepo.findEstadoById(data.estadoId);
    if (!estado) throw AppError.notFound('Estado não encontrado');
    const cidade = await this.locationRepo.createCidade(data);
    res.status(201).json({ cidade });
  };

  deleteCidade = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const exists = await this.locationRepo.findCidadeById(id);
    if (!exists) throw AppError.notFound('Cidade não encontrada');
    await this.locationRepo.deleteCidade(id);
    res.status(204).send();
  };

  // ── Bairros ────────────────────────────────────────────────────────────────

  listBairrosByCidade = async (req: Request, res: Response): Promise<void> => {
    const { cidadeId } = req.params as { cidadeId: string };
    const cidade = await this.locationRepo.findCidadeById(cidadeId);
    if (!cidade) throw AppError.notFound('Cidade não encontrada');
    const bairros = await this.locationRepo.findBairrosByCidade(cidadeId);
    res.json({ bairros });
  };

  createBairro = async (req: Request, res: Response): Promise<void> => {
    const data = createBairroSchema.parse(req.body);
    const cidade = await this.locationRepo.findCidadeById(data.cidadeId);
    if (!cidade) throw AppError.notFound('Cidade não encontrada');
    const bairro = await this.locationRepo.createBairro(data);
    res.status(201).json({ bairro });
  };

  deleteBairro = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const exists = await this.locationRepo.findBairroById(id);
    if (!exists) throw AppError.notFound('Bairro não encontrado');
    await this.locationRepo.deleteBairro(id);
    res.status(204).send();
  };

  // ── Helpers (List all) ─────────────────────────────────────────────────────

  listAllCidades = async (_req: Request, res: Response): Promise<void> => {
    const cidades = await this.locationRepo.findAllCidades();
    res.json({ data: cidades });
  };

  listNeighborhoodsByCidade = async (req: Request, res: Response): Promise<void> => {
    const { cidadeId } = req.query as { cidadeId?: string };
    if (!cidadeId) throw new AppError('cidadeId é obrigatório', 400, 'BAD_REQUEST');
    const cidade = await this.locationRepo.findCidadeById(cidadeId);
    if (!cidade) throw AppError.notFound('Cidade não encontrada');
    const bairros = await this.locationRepo.findBairrosByCidade(cidadeId);
    res.json({ data: bairros });
  };
}
