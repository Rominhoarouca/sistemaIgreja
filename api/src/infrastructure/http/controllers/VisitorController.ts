import type { Request, Response } from 'express';
import { z } from 'zod';
import type { RegisterVisitorUseCase } from '@application/usecases/visitor/RegisterVisitorUseCase';
import type { GetVisitorsUseCase } from '@application/usecases/visitor/GetVisitorsUseCase';
import type { UpdateVisitorStatusUseCase } from '@application/usecases/visitor/UpdateVisitorStatusUseCase';
import type { IVisitorRepository } from '@domain/repositories/IVisitorRepository';
import type { ICellMemberRepository } from '@domain/repositories/ICellMemberRepository';
import { AppError } from '@shared/errors/AppError';

const createSchema = z.object({
  name: z.string().min(2),
  phone: z.string().min(8),
  email: z.string().email().optional(),
  address: z.string().optional(),
  neighborhood: z.string().optional(),
  city: z.string().optional(),
  originChurch: z.string().optional(),
  leaderId: z.string().uuid().optional(),
  cellId: z.string().uuid().optional(),
  referredById: z.string().uuid().optional(),
});

const statusSchema = z.object({
  status: z.enum(['novo', 'em_acompanhamento', 'integrado', 'inativo']),
  leaderId: z.string().uuid().optional(),
  cellId: z.string().uuid().optional(),
});

const assignCellSchema = z.object({
  cellId: z.string().uuid().nullable(),
});

const querySchema = z.object({
  leaderId: z.string().uuid().optional(),
  cellId: z.string().uuid().optional(),
  status: z.enum(['novo', 'em_acompanhamento', 'integrado', 'inativo']).optional(),
  search: z.string().optional(),
  page: z.coerce.number().int().positive().default(1),
  pageSize: z.coerce.number().int().positive().max(100).default(20),
});

const convertSchema = z.object({
  cellId: z.string().uuid().optional(),
});

export class VisitorController {
  constructor(
    private readonly registerUseCase: RegisterVisitorUseCase,
    private readonly getVisitorsUseCase: GetVisitorsUseCase,
    private readonly updateStatusUseCase: UpdateVisitorStatusUseCase,
    private readonly visitorRepo: IVisitorRepository,
    private readonly cellMemberRepo: ICellMemberRepository,
  ) {}

  create = async (req: Request, res: Response): Promise<void> => {
    const data = createSchema.parse(req.body);
    const visitor = await this.registerUseCase.execute(data);
    res.status(201).json({ visitor });
  };

  findAll = async (req: Request, res: Response): Promise<void> => {
    const filters = querySchema.parse(req.query);
    const result = await this.getVisitorsUseCase.execute(filters);
    res.json(result);
  };

  findById = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const visitor = await this.visitorRepo.findById(id);
    if (!visitor) throw AppError.notFound('Visitante não encontrado');
    res.json({ visitor });
  };

  updateStatus = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const data = statusSchema.parse(req.body);
    const visitor = await this.updateStatusUseCase.execute(id, data);
    res.json({ visitor });
  };

  convertToMember = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const { cellId } = convertSchema.parse(req.body ?? {});
    const member = await this.cellMemberRepo.convertVisitorToMember(id, cellId);
    const visitor = await this.visitorRepo.findById(id);
    if (!visitor) throw AppError.notFound('Visitante não encontrado');
    res.json({ member, visitor });
  };

  assignCell = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const { cellId } = assignCellSchema.parse(req.body);
    const visitor = await this.visitorRepo.findById(id);
    if (!visitor) throw AppError.notFound('Visitante não encontrado');
    const updated = await this.visitorRepo.updateStatus(id, {
      status: visitor.status,
      cellId: cellId ?? undefined,
    });
    res.json({ visitor: updated });
  };
}
