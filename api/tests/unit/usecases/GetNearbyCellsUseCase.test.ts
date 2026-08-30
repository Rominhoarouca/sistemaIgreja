import { GetNearbyCellsUseCase } from '@application/usecases/cell/GetNearbyCellsUseCase';
import type { ICellRepository } from '@domain/repositories/ICellRepository';
import type { CellWithDistance } from '@domain/entities/Cell';

const makeCell = (distanceKm: number): CellWithDistance => ({
  id: `cell-${distanceKm}`,
  name: `Célula ${distanceKm}km`,
  leaderId: 'leader-1',
  cellTypeId: null,
  address: 'Rua A, 1',
  bairroId: null,
  neighborhood: 'Centro',
  city: 'São Paulo',
  state: 'SP',
  dayOfWeek: 'quarta',
  time: '19:30',
  maxCapacity: 20,
  currentCount: 5,
  latitude: -23.55,
  longitude: -46.63,
  createdAt: new Date(),
  updatedAt: new Date(),
  distanceKm,
});

const makeRepo = (cells: CellWithDistance[]): ICellRepository => ({
  findById: jest.fn(),
  findAll: jest.fn(),
  findByLeaderId: jest.fn(),
  findWithoutLeader: jest.fn(),
  findNearby: jest.fn().mockResolvedValue(cells),
  create: jest.fn(),
  update: jest.fn(),
  delete: jest.fn(),
  count: jest.fn(),
});

describe('GetNearbyCellsUseCase', () => {
  it('deve retornar células próximas ordenadas por distância', async () => {
    const cells = [makeCell(3.2), makeCell(1.5), makeCell(8.0)];
    const repo = makeRepo(cells);
    const useCase = new GetNearbyCellsUseCase(repo);

    const result = await useCase.execute({ latitude: -23.55, longitude: -46.63, radiusKm: 10 });

    expect(repo.findNearby).toHaveBeenCalledWith({
      latitude: -23.55,
      longitude: -46.63,
      radiusKm: 10,
    });
    expect(result).toHaveLength(3);
  });

  it('deve retornar lista vazia se nenhuma célula no raio', async () => {
    const repo = makeRepo([]);
    const useCase = new GetNearbyCellsUseCase(repo);
    const result = await useCase.execute({ latitude: -23.55, longitude: -46.63, radiusKm: 5 });
    expect(result).toHaveLength(0);
  });
});
