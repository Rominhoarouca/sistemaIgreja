import bcrypt from 'bcryptjs';
import { randomUUID } from 'crypto';
import type { IUserRepository } from '@domain/repositories/IUserRepository';
import type { User, UserRole } from '@domain/entities/User';
import { AppError } from '@shared/errors/AppError';

interface RegisterUserInput {
  readonly name: string;
  readonly email: string;
  readonly password: string;
  readonly role: UserRole;
  readonly churchId?: string | null;
}

export class RegisterUserUseCase {
  constructor(private readonly userRepo: IUserRepository) {}

  async execute(input: RegisterUserInput): Promise<User> {
    const existing = await this.userRepo.findByEmail(input.email);
    if (existing) {
      throw AppError.conflict('E-mail já cadastrado');
    }

    const hashed = await bcrypt.hash(input.password, 12);
    const user = await this.userRepo.save({
      id: randomUUID(),
      churchId: input.churchId ?? null,
      name: input.name,
      email: input.email,
      password: hashed,
      role: input.role,
      roles: [input.role],
      photoKey: null,
      phone: null,
      address: null,
      birthDate: null,
      isMarried: false,
      spouseName: null,
      weddingDate: null,
      supervisorId: null,
      coordenacaoId: null,
      description: null,
    });

    return user;
  }
}
