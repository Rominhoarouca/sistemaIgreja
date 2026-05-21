import type { IUserRepository } from '@domain/repositories/IUserRepository';
import type { UserProfile } from '@domain/entities/User';
import type { MinioService } from '@infrastructure/storage/MinioService';
import { AppError } from '@shared/errors/AppError';

export interface GetProfileOutput extends UserProfile {
  photoUrl: string | null;
}

export class GetProfileUseCase {
  constructor(
    private readonly userRepo: IUserRepository,
    private readonly minioService: MinioService,
  ) {}

  async execute(userId: string): Promise<GetProfileOutput> {
    const user = await this.userRepo.getProfile(userId);
    if (!user) throw AppError.notFound('Usuário não encontrado');

    let photoUrl: string | null = null;
    if (user.photoKey) {
      photoUrl = await this.minioService.presignedDownloadUrl(user.photoKey);
    }

    return { ...user, photoUrl };
  }
}
