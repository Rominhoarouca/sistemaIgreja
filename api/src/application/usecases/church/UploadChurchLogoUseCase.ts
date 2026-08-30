import { randomUUID } from 'crypto';
import type { IChurchRepository } from '@domain/repositories/IChurchRepository';
import type { Church } from '@domain/entities/Church';
import { MinioService, StorageFolder } from '@infrastructure/storage/MinioService';
import { AppError } from '@shared/errors/AppError';

interface UploadLogoInput {
  readonly churchId: string;
  readonly buffer: Buffer;
  readonly mimeType: string;
  readonly size: number;
  readonly originalName: string;
}

const ALLOWED = ['image/png', 'image/jpeg', 'image/jpg', 'image/webp', 'image/svg+xml'];

export class UploadChurchLogoUseCase {
  constructor(
    private readonly churchRepo: IChurchRepository,
    private readonly minio: MinioService,
  ) {}

  async execute(input: UploadLogoInput): Promise<{ church: Church; logoUrl: string }> {
    if (!ALLOWED.includes(input.mimeType)) {
      throw new AppError('Formato de logo inválido (use PNG, JPG, WEBP ou SVG)', 400);
    }
    const church = await this.churchRepo.findById(input.churchId);
    if (!church) throw AppError.notFound('Igreja não encontrada');

    const ext = input.originalName.split('.').pop() ?? 'png';
    const objectName = MinioService.objectKey(
      StorageFolder.logo,
      `${randomUUID()}.${ext}`,
    );

    // churchId explícito: o upload da logo também roda para o SUPERADMIN, que
    // não tem igreja no contexto de tenant.
    await this.minio.uploadFile({
      objectName,
      buffer: input.buffer,
      mimeType: input.mimeType,
      size: input.size,
      churchId: input.churchId,
    });

    // Remove logo anterior (best-effort).
    if (church.logoKey) {
      try {
        await this.minio.deleteObject(church.logoKey, input.churchId);
      } catch {
        /* ignore */
      }
    }

    const updated = await this.churchRepo.updateLogoKey(input.churchId, objectName);
    const logoUrl = await this.minio.presignedDownloadUrl(objectName, 3600, input.churchId);
    return { church: updated, logoUrl };
  }
}
