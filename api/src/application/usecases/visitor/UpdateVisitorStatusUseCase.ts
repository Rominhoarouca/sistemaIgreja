import type { IVisitorRepository } from '@domain/repositories/IVisitorRepository';
import type { Visitor, UpdateVisitorStatusData } from '@domain/entities/Visitor';
import { AppError } from '@shared/errors/AppError';

export class UpdateVisitorStatusUseCase {
  constructor(private readonly visitorRepo: IVisitorRepository) {}

  async execute(id: string, data: UpdateVisitorStatusData): Promise<Visitor> {
    const visitor = await this.visitorRepo.findById(id);
    if (!visitor) throw AppError.notFound('Visitante não encontrado');
    return this.visitorRepo.updateStatus(id, data);
  }
}
