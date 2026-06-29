import type { Coordenacao, CoordenacaoWithDetails } from '../entities/Coordenacao';

export interface CreateCoordenacaoData {
  name: string;
  color: string;
  coordinadorId: string;
}

export interface UpdateCoordenacaoData {
  name?: string | undefined;
  color?: string | undefined;
}

export interface ICoordenacaoRepository {
  findAll(): Promise<CoordenacaoWithDetails[]>;
  findById(id: string): Promise<Coordenacao | null>;
  findByCoordinadorId(coordinadorId: string): Promise<Coordenacao | null>;
  create(data: CreateCoordenacaoData): Promise<Coordenacao>;
  update(id: string, data: UpdateCoordenacaoData): Promise<Coordenacao>;
  delete(id: string): Promise<void>;
}
