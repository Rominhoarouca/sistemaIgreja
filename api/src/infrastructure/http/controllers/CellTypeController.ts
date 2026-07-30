import type { Request, Response } from 'express';
import { z } from 'zod';
import { PrismaClient } from '@prisma/client';
import { AppError } from '@shared/errors/AppError';

const createSchema = z.object({
  name: z.string().min(2),
  description: z.string().optional(),
});

const updateSchema = z.object({
  name: z.string().min(2).optional(),
  description: z.string().nullable().optional(),
});

export class CellTypeController {
  constructor(private readonly prisma: PrismaClient) {}

  findAll = async (_req: Request, res: Response): Promise<void> => {
    const types = await this.prisma.cellType.findMany({
      orderBy: { name: 'asc' },
    });
    res.json({ cellTypes: types });
  };

  create = async (req: Request, res: Response): Promise<void> => {
    const data = createSchema.parse(req.body);
    const exists = await this.prisma.cellType.findFirst({ where: { name: data.name } });
    if (exists) throw new AppError('Já existe um tipo de célula com esse nome', 409);
    const cellType = await this.prisma.cellType.create({ data: { name: data.name, description: data.description ?? null } });
    res.status(201).json({ cellType });
  };

  update = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const data = updateSchema.parse(req.body);
    const exists = await this.prisma.cellType.findUnique({ where: { id } });
    if (!exists) throw AppError.notFound('Tipo de célula não encontrado');
    if (data.name && data.name !== exists.name) {
      const nameConflict = await this.prisma.cellType.findFirst({ where: { name: data.name } });
      if (nameConflict) throw new AppError('Já existe um tipo de célula com esse nome', 409);
    }
    const cellType = await this.prisma.cellType.update({
      where: { id },
      data: {
        ...(data.name !== undefined && { name: data.name }),
        ...(data.description !== undefined && { description: data.description }),
      },
    });
    res.json({ cellType });
  };

  delete = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const exists = await this.prisma.cellType.findUnique({ where: { id } });
    if (!exists) throw AppError.notFound('Tipo de célula não encontrado');
    await this.prisma.cellType.delete({ where: { id } });
    res.status(204).send();
  };
}
