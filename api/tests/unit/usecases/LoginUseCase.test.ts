import { LoginUseCase } from '@application/usecases/auth/LoginUseCase';
import type { IUserRepository } from '@domain/repositories/IUserRepository';
import type { IRefreshTokenRepository } from '@domain/repositories/IRefreshTokenRepository';
import type { UserWithPassword } from '@domain/entities/User';
import { AppError } from '@shared/errors/AppError';
import bcrypt from 'bcryptjs';

let mockUser: UserWithPassword;

const makeUserRepo = (user: UserWithPassword | null): IUserRepository => ({
  findById: jest.fn(),
  findByEmail: jest.fn().mockResolvedValue(user),
  save: jest.fn(),
});

const makeRefreshRepo = (): IRefreshTokenRepository => ({
  create: jest.fn().mockResolvedValue({}),
  findByToken: jest.fn(),
  deleteByToken: jest.fn(),
  deleteByUserId: jest.fn(),
});

beforeAll(async () => {
  const password = await bcrypt.hash('secret123', 10);
  mockUser = {
    id: 'user-1',
    name: 'Admin Test',
    email: 'admin@test.com',
    password,
    role: 'ADMIN',
    createdAt: new Date(),
    updatedAt: new Date(),
  };
  process.env['JWT_SECRET'] = 'test_secret_key_256bits_minimum_length_required';
  process.env['JWT_REFRESH_SECRET'] = 'test_refresh_secret_key_256bits_minimum_length';
  process.env['JWT_EXPIRES_IN'] = '15m';
  process.env['JWT_REFRESH_EXPIRES_IN'] = '7d';
});

describe('LoginUseCase', () => {
  it('deve retornar tokens e usuário com credenciais válidas', async () => {
    const useCase = new LoginUseCase(makeUserRepo(mockUser), makeRefreshRepo());
    const result = await useCase.execute({ email: 'admin@test.com', password: 'secret123' });

    expect(result.accessToken).toBeDefined();
    expect(result.refreshToken).toBeDefined();
    expect(result.user.email).toBe(mockUser.email);
    expect((result.user as UserWithPassword).password).toBeUndefined();
  });

  it('deve lançar erro com senha incorreta', async () => {
    const useCase = new LoginUseCase(makeUserRepo(mockUser), makeRefreshRepo());
    await expect(
      useCase.execute({ email: 'admin@test.com', password: 'wrong' }),
    ).rejects.toBeInstanceOf(AppError);
  });

  it('deve lançar erro com email não cadastrado', async () => {
    const useCase = new LoginUseCase(makeUserRepo(null), makeRefreshRepo());
    await expect(
      useCase.execute({ email: 'naoexiste@test.com', password: 'secret123' }),
    ).rejects.toBeInstanceOf(AppError);
  });
});
