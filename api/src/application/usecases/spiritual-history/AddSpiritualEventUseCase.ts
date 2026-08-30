import type { ISpiritualHistoryRepository } from '@domain/repositories/ISpiritualHistoryRepository';
import type { IVisitorRepository } from '@domain/repositories/IVisitorRepository';
import type { ICellMemberRepository } from '@domain/repositories/ICellMemberRepository';
import type { SpiritualHistory, AddSpiritualEventData } from '@domain/entities/SpiritualHistory';
import { AppError } from '@shared/errors/AppError';

export class AddSpiritualEventUseCase {
  constructor(
    private readonly spiritualHistoryRepo: ISpiritualHistoryRepository,
    private readonly visitorRepo: IVisitorRepository,
    private readonly cellMemberRepo: ICellMemberRepository,
  ) {}

  async execute(data: AddSpiritualEventData): Promise<SpiritualHistory> {
    if ((data.visitorId == null) === (data.memberId == null)) {
      throw new AppError(
        'Informe exatamente um entre visitante e membro',
        400,
        'PERSON_REQUIRED',
      );
    }

    if (data.visitorId != null) {
      const visitor = await this.visitorRepo.findById(data.visitorId);
      if (!visitor) throw AppError.notFound('Visitante não encontrado');
    } else {
      const member = await this.cellMemberRepo.findById(data.memberId!);
      if (!member) throw AppError.notFound('Membro não encontrado');
    }

    const event = await this.spiritualHistoryRepo.add(data);

    // Registrar o batismo é o que marca a pessoa como batizada — evita o
    // cadastro contradizer o histórico.
    if (data.eventType === 'batizado') {
      if (data.visitorId != null) {
        await this.visitorRepo.setBaptized(data.visitorId, true);
      } else {
        await this.cellMemberRepo.update(data.memberId!, { isBaptized: true });
      }
    }

    return event;
  }
}
