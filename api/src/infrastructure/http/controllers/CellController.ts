import type { Request, Response } from 'express';
import { z } from 'zod';
import type { GetNearbyCellsUseCase } from '@application/usecases/cell/GetNearbyCellsUseCase';
import type { ICellRepository } from '@domain/repositories/ICellRepository';
import type { ICellMemberRepository } from '@domain/repositories/ICellMemberRepository';
import { AppError } from '@shared/errors/AppError';

const nearbySchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  radius: z.coerce.number().positive().max(100).default(10),
});

const createCellSchema = z.object({
  name: z.string().min(2),
  leaderId: z.string().uuid(),
  address: z.string().min(3),
  neighborhood: z.string().min(2),
  city: z.string().min(2),
  dayOfWeek: z.enum(['segunda', 'terca', 'quarta', 'quinta', 'sexta', 'sabado', 'domingo']),
  time: z.string().regex(/^\d{2}:\d{2}$/, 'Horário deve ser HH:MM'),
  maxCapacity: z.coerce.number().int().positive().optional(),
  latitude: z.coerce.number().optional(),
  longitude: z.coerce.number().optional(),
});

const updateCellSchema = z.object({
  name: z.string().min(2).optional(),
  leaderId: z.string().uuid().optional(),
  address: z.string().min(3).optional(),
  neighborhood: z.string().min(2).optional(),
  city: z.string().min(2).optional(),
  dayOfWeek: z.enum(['segunda', 'terca', 'quarta', 'quinta', 'sexta', 'sabado', 'domingo']).optional(),
  time: z.string().regex(/^\d{2}:\d{2}$/, 'Horário deve ser HH:MM').optional(),
  maxCapacity: z.coerce.number().int().nonnegative().optional(),
  latitude: z.coerce.number().nullable().optional(),
  longitude: z.coerce.number().nullable().optional(),
});

const createMemberSchema = z.object({
  name: z.string().min(2),
  phone: z.string().min(8),
  email: z.string().email().optional(),
  address: z.string().optional(),
  neighborhood: z.string().optional(),
  city: z.string().optional(),
  leaderId: z.string().uuid().optional(),
});

export class CellController {
  constructor(
    private readonly getNearbyCellsUseCase: GetNearbyCellsUseCase,
    private readonly cellRepo: ICellRepository,
    private readonly cellMemberRepo: ICellMemberRepository,
  ) {}

  findNearby = async (req: Request, res: Response): Promise<void> => {
    const { lat, lng, radius } = nearbySchema.parse(req.query);
    const cells = await this.getNearbyCellsUseCase.execute({
      latitude: lat,
      longitude: lng,
      radiusKm: radius,
    });
    res.json({ cells });
  };

  findAll = async (_req: Request, res: Response): Promise<void> => {
    const cells = await this.cellRepo.findAll();
    res.json({ cells });
  };

  findById = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const cell = await this.cellRepo.findById(id);
    if (!cell) throw AppError.notFound('Célula não encontrada');
    res.json({ cell });
  };

  create = async (req: Request, res: Response): Promise<void> => {
    const data = createCellSchema.parse(req.body);
    const cell = await this.cellRepo.create(data);
    res.status(201).json({ cell });
  };

  update = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const data = updateCellSchema.parse(req.body);
    const exists = await this.cellRepo.findById(id);
    if (!exists) throw AppError.notFound('Célula não encontrada');
    const cell = await this.cellRepo.update(id, data);
    res.json({ cell });
  };

  delete = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const exists = await this.cellRepo.findById(id);
    if (!exists) throw AppError.notFound('Célula não encontrada');
    await this.cellRepo.delete(id);
    res.status(204).send();
  };

  listMembers = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const cell = await this.cellRepo.findById(id);
    if (!cell) throw AppError.notFound('Célula não encontrada');
    const members = await this.cellMemberRepo.findByCellId(id);
    res.json({ members });
  };

  addMember = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const cell = await this.cellRepo.findById(id);
    if (!cell) throw AppError.notFound('Célula não encontrada');

    const data = createMemberSchema.parse(req.body);
    const member = await this.cellMemberRepo.create({
      cellId: id,
      ...data,
    });

    res.status(201).json({ member });
  };

  findByLeader = async (req: Request, res: Response): Promise<void> => {
    const cells = await this.cellRepo.findByLeaderId(req.userId);
    res.json({ cells });
  };
}
