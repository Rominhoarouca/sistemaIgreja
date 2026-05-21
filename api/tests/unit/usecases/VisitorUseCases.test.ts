import { RegisterVisitorUseCase } from '@application/usecases/visitor/RegisterVisitorUseCase';
import { GetVisitorsUseCase } from '@application/usecases/visitor/GetVisitorsUseCase';
import { UpdateVisitorStatusUseCase } from '@application/usecases/visitor/UpdateVisitorStatusUseCase';
import type { IVisitorRepository } from '@domain/repositories/IVisitorRepository';
import type { Visitor, PaginatedVisitors } from '@domain/entities/Visitor';
import { AppError } from '@shared/errors/AppError';

const baseVisitor: Visitor = {
  id: 'v-1',
  name: 'Maria Santos',
  phone: '11999990001',
  email: null,
  address: null,
  neighborhood: null,
  city: null,
  originChurch: null,
  status: 'novo',
  leaderId: null,
  cellId: null,
  referredById: null,
  createdAt: new Date(),
  updatedAt: new Date(),
};

const makePaginated = (data: Visitor[]): PaginatedVisitors => ({
  data,
  total: data.length,
  page: 1,
  pageSize: 20,
  totalPages: 1,
});

const makeRepo = (overrides: Partial<IVisitorRepository> = {}): IVisitorRepository => ({
  findById: jest.fn().mockResolvedValue(baseVisitor),
  findMany: jest.fn().mockResolvedValue(makePaginated([baseVisitor])),
  create: jest.fn().mockResolvedValue(baseVisitor),
  updateStatus: jest.fn().mockResolvedValue({ ...baseVisitor, status: 'integrado' }),
  countByStatus: jest.fn().mockResolvedValue({ novo: 1 }),
  countNewThisMonth: jest.fn().mockResolvedValue(1),
  ...overrides,
});

describe('RegisterVisitorUseCase', () => {
  it('deve criar um visitante e retorná-lo', async () => {
    const repo = makeRepo();
    const useCase = new RegisterVisitorUseCase(repo);
    const result = await useCase.execute({ name: 'Maria Santos', phone: '11999990001' });
    expect(result.name).toBe('Maria Santos');
    expect(repo.create).toHaveBeenCalledWith({ name: 'Maria Santos', phone: '11999990001' });
  });
});

describe('GetVisitorsUseCase', () => {
  it('deve retornar lista paginada de visitantes', async () => {
    const repo = makeRepo();
    const useCase = new GetVisitorsUseCase(repo);
    const result = await useCase.execute({ page: 1, pageSize: 20 });
    expect(result.data).toHaveLength(1);
    expect(result.totalPages).toBe(1);
  });
});

describe('UpdateVisitorStatusUseCase', () => {
  it('deve atualizar o status do visitante', async () => {
    const repo = makeRepo();
    const useCase = new UpdateVisitorStatusUseCase(repo);
    const result = await useCase.execute('v-1', { status: 'integrado' });
    expect(result.status).toBe('integrado');
  });

  it('deve lançar erro se visitante não existir', async () => {
    const repo = makeRepo({ findById: jest.fn().mockResolvedValue(null) });
    const useCase = new UpdateVisitorStatusUseCase(repo);
    await expect(useCase.execute('inexistente', { status: 'integrado' })).rejects.toBeInstanceOf(
      AppError,
    );
  });
});
