import type { ISpiritualHistoryRepository } from '@domain/repositories/ISpiritualHistoryRepository';
import type { IVisitorRepository } from '@domain/repositories/IVisitorRepository';
import type { SpiritualHistory, AddSpiritualEventData } from '@domain/entities/SpiritualHistory';
import { AppError } from '@shared/errors/AppError';

export class AddSpiritualEventUseCase {
  constructor(
    private readonly spiritualHistoryRepo: ISpiritualHistoryRepository,
    private readonly visitorRepo: IVisitorRepository,
  ) {}

  async execute(data: AddSpiritualEventData): Promise<SpiritualHistory> {
    const visitor = await this.visitorRepo.findById(data.visitorId);
    if (!visitor) throw AppError.notFound('Visitante não encontrado');
    return this.spiritualHistoryRepo.add(data);
  }
}
