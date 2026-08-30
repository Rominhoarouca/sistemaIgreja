import type { Cell, CellWithDistance, NearbySearchParams, CreateCellData } from '../entities/Cell';

export interface ICellRepository {
  findById(id: string): Promise<Cell | null>;
  findAll(): Promise<Cell[]>;
  findByLeaderId(leaderId: string): Promise<Cell[]>;
  /** Células ainda sem líder vinculado. */
  findWithoutLeader(): Promise<Cell[]>;
  findNearby(params: NearbySearchParams): Promise<CellWithDistance[]>;
  create(data: CreateCellData): Promise<Cell>;
  update(id: string, data: Partial<CreateCellData>): Promise<Cell>;
  delete(id: string): Promise<void>;
  count(): Promise<number>;
}
