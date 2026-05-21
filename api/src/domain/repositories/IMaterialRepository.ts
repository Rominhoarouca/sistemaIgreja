import type { Material, CreateMaterialData } from '../entities/Material';

export interface IMaterialRepository {
  findById(id: string): Promise<Material | null>;
  findByCell(cellId: string): Promise<Material[]>;
  findAll(): Promise<Material[]>;
  create(data: CreateMaterialData): Promise<Material>;
  delete(id: string): Promise<void>;
}
