import type {
  Estado,
  Cidade,
  Bairro,
  CreateEstadoData,
  CreateCidadeData,
  CreateBairroData,
} from '@domain/entities/Location';

export interface ILocationRepository {
  findAllEstados(): Promise<Estado[]>;
  findEstadoById(id: string): Promise<Estado | null>;
  createEstado(data: CreateEstadoData): Promise<Estado>;
  deleteEstado(id: string): Promise<void>;

  findAllCidades(): Promise<Cidade[]>;
  findCidadesByEstado(estadoId: string): Promise<Cidade[]>;
  findCidadeById(id: string): Promise<Cidade | null>;
  createCidade(data: CreateCidadeData): Promise<Cidade>;
  deleteCidade(id: string): Promise<void>;

  findBairrosByCidade(cidadeId: string): Promise<Bairro[]>;
  findBairroById(id: string): Promise<Bairro | null>;
  createBairro(data: CreateBairroData): Promise<Bairro>;
  deleteBairro(id: string): Promise<void>;
}
