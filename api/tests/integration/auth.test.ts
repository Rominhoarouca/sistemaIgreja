import request from 'supertest';
import bcrypt from 'bcryptjs';
import { createApp } from '@infrastructure/http/app';
import { createContainer } from '@shared/container';
import type { Container } from '@shared/container';
import type { User, UserWithPassword } from '@domain/entities/User';
import type { RefreshToken } from '@domain/entities/RefreshToken';

// ── In-memory fakes ──────────────────────────────────────────────────────────
let storedUser: UserWithPassword | null = null;
let storedRefreshToken: RefreshToken | null = null;

const fakeUserRepo = {
  findById: jest.fn(async (id: string) =>
    storedUser && storedUser.id === id
      ? (({ password: _p, ...u }) => u)(storedUser) as User
      : null,
  ),
  findByEmail: jest.fn(async (email: string) =>
    storedUser && storedUser.email === email ? storedUser : null,
  ),
  save: jest.fn(),
};

const fakeRefreshRepo = {
  create: jest.fn(async (data: { token: string; userId: string; expiresAt: Date }) => {
    storedRefreshToken = { id: 'rt-1', ...data, createdAt: new Date() };
    return storedRefreshToken;
  }),
  findByToken: jest.fn(async (token: string) =>
    storedRefreshToken?.token === token ? storedRefreshToken : null,
  ),
  deleteByToken: jest.fn(async () => { storedRefreshToken = null; }),
  deleteByUserId: jest.fn(),
};

// ── Setup ────────────────────────────────────────────────────────────────────
let app: ReturnType<typeof createApp>;

beforeAll(async () => {
  process.env['JWT_SECRET'] = 'integration_test_jwt_secret_key_256bits_min';
  process.env['JWT_REFRESH_SECRET'] = 'integration_test_refresh_secret_256bits_min';
  process.env['JWT_EXPIRES_IN'] = '15m';
  process.env['JWT_REFRESH_EXPIRES_IN'] = '7d';

  const hash = await bcrypt.hash('pass1234', 10);
  storedUser = {
    id: 'u-1',
    name: 'Tester',
    email: 'tester@test.com',
    password: hash,
    role: 'ADMIN',
    createdAt: new Date(),
    updatedAt: new Date(),
  };

  const container = createContainer() as Container;
  // Replace repos with in-memory fakes
  (container.authController as unknown as { userRepo: typeof fakeUserRepo }).userRepo = fakeUserRepo;

  // Build app with a simplified container using fakes
  const { LoginUseCase } = await import('@application/usecases/auth/LoginUseCase');
  const { RefreshTokenUseCase } = await import('@application/usecases/auth/RefreshTokenUseCase');
  const { AuthController } = await import('@infrastructure/http/controllers/AuthController');
  const loginUseCase = new LoginUseCase(fakeUserRepo as never, fakeRefreshRepo as never);
  const refreshUseCase = new RefreshTokenUseCase(fakeUserRepo as never, fakeRefreshRepo as never);
  const authCtrl = new AuthController(loginUseCase, refreshUseCase, fakeRefreshRepo as never, fakeUserRepo as never);
  container.authController = authCtrl;

  app = createApp(container);
});

describe('POST /v1/auth/login', () => {
  it('200 com credenciais válidas', async () => {
    const res = await request(app)
      .post('/v1/auth/login')
      .send({ email: 'tester@test.com', password: 'pass1234' });

    expect(res.status).toBe(200);
    expect(res.body).toHaveProperty('accessToken');
    expect(res.body).toHaveProperty('refreshToken');
    expect(res.body.user.email).toBe('tester@test.com');
    expect(res.body.user.password).toBeUndefined();
  });

  it('401 com senha errada', async () => {
    const res = await request(app)
      .post('/v1/auth/login')
      .send({ email: 'tester@test.com', password: 'wrong' });
    expect(res.status).toBe(401);
  });

  it('422 sem email', async () => {
    const res = await request(app).post('/v1/auth/login').send({ password: 'pass1234' });
    expect(res.status).toBe(422);
  });
});

describe('GET /health', () => {
  it('200 ok', async () => {
    const res = await request(app).get('/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });
});
