import type { IUserRepository } from '@domain/repositories/IUserRepository';
import type { User, Child } from '@domain/entities/User';
import type { MinioService } from '@infrastructure/storage/MinioService';
import { AppError } from '@shared/errors/AppError';
import path from 'path';

interface ChildInput {
  id?: string | undefined;
  name: string;
  birthDate?: string | null | undefined;
}

interface UpdateProfileInput {
  userId: string;
  name?: string;
  phone?: string | null;
  address?: string | null;
  birthDate?: string | null;
  children?: ChildInput[];
  fileBuffer?: Buffer;
  mimeType?: string;
  originalName?: string;
}

interface UpdateProfileOutput {
  user: User;
  children: Child[];
}

export class UpdateProfileUseCase {
  constructor(
    private readonly userRepo: IUserRepository,
    private readonly minioService: MinioService,
  ) {}

  async execute(input: UpdateProfileInput): Promise<UpdateProfileOutput> {
    const existing = await this.userRepo.findById(input.userId);
    if (!existing) throw AppError.notFound('Usuário não encontrado');

    let photoKey: string | undefined;
    if (input.fileBuffer && input.mimeType && input.originalName) {
      const ext = path.extname(input.originalName).toLowerCase() || '.jpg';
      const objectName = `users/${input.userId}/photo${ext}`;
      await this.minioService.uploadFile({
        objectName,
        buffer: input.fileBuffer,
        mimeType: input.mimeType,
        size: input.fileBuffer.length,
      });
      photoKey = objectName;
    }

    const user = await this.userRepo.updateProfile(input.userId, {
      ...(input.name !== undefined && { name: input.name }),
      ...(input.phone !== undefined && { phone: input.phone }),
      ...(input.address !== undefined && { address: input.address }),
      ...(input.birthDate !== undefined && {
        birthDate: input.birthDate ? new Date(input.birthDate) : null,
      }),
      ...(photoKey !== undefined && { photoKey }),
    });

    const childrenInput = (input.children ?? []).map((c) => ({
      ...(c.id !== undefined && { id: c.id }),
      name: c.name,
      ...(c.birthDate !== undefined && { birthDate: c.birthDate ? new Date(c.birthDate) : null }),
    }));

    const children = await this.userRepo.upsertChildren(input.userId, childrenInput);

    return { user, children };
  }
}
