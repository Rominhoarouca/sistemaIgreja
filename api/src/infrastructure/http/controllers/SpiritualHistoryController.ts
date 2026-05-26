import type { Request, Response } from 'express';
import { z } from 'zod';
import type { AddSpiritualEventUseCase } from '@application/usecases/spiritual-history/AddSpiritualEventUseCase';
import type { ISpiritualHistoryRepository } from '@domain/repositories/ISpiritualHistoryRepository';

const addEventSchema = z.object({
  visitorId: z.string().uuid(),
  eventType: z.enum([
    'enviado_batismo',
    'batizado',
    'enviado_treinamento_lider',
    'concluiu_treinamento',
    'tornou_se_lider',
  ]),
  description: z.string().optional(),
  date: z.string().date(),
});

export class SpiritualHistoryController {
  constructor(
    private readonly addEventUseCase: AddSpiritualEventUseCase,
    private readonly spiritualHistoryRepo: ISpiritualHistoryRepository,
  ) {}

  addEvent = async (req: Request, res: Response): Promise<void> => {
    const data = addEventSchema.parse(req.body);
    const event = await this.addEventUseCase.execute({
      ...data,
      date: new Date(data.date),
      recordedById: req.userId,
    });
    res.status(201).json({ event });
  };

  findByVisitor = async (req: Request, res: Response): Promise<void> => {
    const { visitorId } = req.params as { visitorId: string };
    const history = await this.spiritualHistoryRepo.findByVisitor(visitorId);
    res.json({ history });
  };

  findByCell = async (req: Request, res: Response): Promise<void> => {
    const { cellId } = req.params as { cellId: string };
    const history = await this.spiritualHistoryRepo.findByCellId(cellId);
    res.json({ history });
  };
}
