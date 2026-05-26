import type {
  Visitor,
  CreateVisitorData,
  UpdateVisitorStatusData,
  VisitorFilters,
  PaginatedVisitors,
} from '../entities/Visitor';

export interface IVisitorRepository {
  findById(id: string): Promise<Visitor | null>;
  findMany(filters: VisitorFilters): Promise<PaginatedVisitors>;
  create(data: CreateVisitorData): Promise<Visitor>;
  updateStatus(id: string, data: UpdateVisitorStatusData): Promise<Visitor>;
  countByStatus(): Promise<Record<string, number>>;
  countNewThisMonth(): Promise<number>;
  countByMonth(months: number): Promise<Array<{ month: string; total: number; integrated: number }>>;
}
