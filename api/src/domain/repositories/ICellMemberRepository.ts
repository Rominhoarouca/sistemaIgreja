import type {
  CellMember,
  CreateCellMemberData,
  UpdateCellMemberData,
} from '@domain/entities/CellMember';

export interface ICellMemberRepository {
  findByCellId(cellId: string): Promise<CellMember[]>;
  findById(id: string): Promise<CellMember | null>;
  create(data: CreateCellMemberData): Promise<CellMember>;
  update(id: string, data: UpdateCellMemberData): Promise<CellMember>;
  delete(id: string): Promise<void>;
  convertVisitorToMember(visitorId: string, cellId?: string): Promise<CellMember>;
}
