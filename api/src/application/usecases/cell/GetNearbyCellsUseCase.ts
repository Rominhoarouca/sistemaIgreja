import type { ICellRepository } from '@domain/repositories/ICellRepository';
import type { CellWithDistance, NearbySearchParams } from '@domain/entities/Cell';

export class GetNearbyCellsUseCase {
  constructor(private readonly cellRepo: ICellRepository) {}

  async execute(params: NearbySearchParams): Promise<CellWithDistance[]> {
    return this.cellRepo.findNearby(params);
  }
}
