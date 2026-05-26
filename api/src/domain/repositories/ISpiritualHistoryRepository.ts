import type { SpiritualHistory, AddSpiritualEventData } from '../entities/SpiritualHistory';

export type SpiritualHistoryWithVisitor = SpiritualHistory & { visitorName: string };

export interface ISpiritualHistoryRepository {
  findByVisitor(visitorId: string): Promise<SpiritualHistory[]>;
  findByCellId(cellId: string): Promise<SpiritualHistoryWithVisitor[]>;
  add(data: AddSpiritualEventData): Promise<SpiritualHistory>;
}
