import type { CellMember, CreateCellMemberData } from '@domain/entities/CellMember';

export interface ICellMemberRepository {
  findByCellId(cellId: string): Promise<CellMember[]>;
  create(data: CreateCellMemberData): Promise<CellMember>;
  convertVisitorToMember(visitorId: string, cellId?: string): Promise<CellMember>;
}
