import type { Church, CreateChurchData, UpdateChurchData } from '../entities/Church';

export interface IChurchRepository {
  findById(id: string): Promise<Church | null>;
  findBySlug(slug: string): Promise<Church | null>;
  findAll(): Promise<Church[]>;
  create(data: CreateChurchData): Promise<Church>;
  update(id: string, data: UpdateChurchData): Promise<Church>;
  updateLogoKey(id: string, logoKey: string): Promise<Church>;
  setActive(id: string, isActive: boolean): Promise<Church>;
}
