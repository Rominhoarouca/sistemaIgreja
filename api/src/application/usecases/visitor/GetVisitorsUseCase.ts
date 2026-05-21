import type { IVisitorRepository } from '@domain/repositories/IVisitorRepository';
import type { PaginatedVisitors, VisitorFilters } from '@domain/entities/Visitor';

export class GetVisitorsUseCase {
  constructor(private readonly visitorRepo: IVisitorRepository) {}

  async execute(filters: VisitorFilters): Promise<PaginatedVisitors> {
    return this.visitorRepo.findMany(filters);
  }
}
