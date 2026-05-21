import type { SpiritualHistory, AddSpiritualEventData } from '../entities/SpiritualHistory';

export interface ISpiritualHistoryRepository {
  findByVisitor(visitorId: string): Promise<SpiritualHistory[]>;
  add(data: AddSpiritualEventData): Promise<SpiritualHistory>;
}
