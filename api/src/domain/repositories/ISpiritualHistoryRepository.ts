import type { SpiritualHistory, AddSpiritualEventData } from '../entities/SpiritualHistory';

/**
 * Evento com o nome da pessoa resolvido. `visitorName` é mantido pelo nome
 * antigo por compatibilidade com o app; `personKind` diz de onde veio.
 */
export type SpiritualHistoryWithVisitor = SpiritualHistory & {
  visitorName: string;
  personKind: 'VISITOR' | 'MEMBER';
};

export interface ISpiritualHistoryRepository {
  findByVisitor(visitorId: string): Promise<SpiritualHistory[]>;
  findByMember(memberId: string): Promise<SpiritualHistory[]>;
  findByCellId(cellId: string): Promise<SpiritualHistoryWithVisitor[]>;
  add(data: AddSpiritualEventData): Promise<SpiritualHistory>;
}
