import type { INotificationRepository } from '@domain/repositories/INotificationRepository';
import type { Notification } from '@domain/entities/Notification';
import type { MinioService } from '@infrastructure/storage/MinioService';
import { v4 as uuidv4 } from 'uuid';
import path from 'path';

interface UpdateNotificationInput {
  id: string;
  title?: string;
  body?: string;
  youtubeUrl?: string;
  previousImageKey: string | null;
  removeImage?: boolean;
  imageBuffer?: Buffer;
  imageMimeType?: string;
  imageOriginalName?: string;
  imageSizeBytes?: number;
}

export class UpdateNotificationUseCase {
  constructor(
    private readonly notificationRepo: INotificationRepository,
    private readonly minioService: MinioService,
  ) {}

  async execute(input: UpdateNotificationInput): Promise<Notification> {
    let imageKey: string | null | undefined;

    if (input.imageBuffer && input.imageMimeType && input.imageOriginalName && input.imageSizeBytes) {
      const ext = path.extname(input.imageOriginalName).toLowerCase();
      const objectName = `notifications/${uuidv4()}${ext}`;
      await this.minioService.uploadFile({
        objectName,
        buffer: input.imageBuffer,
        mimeType: input.imageMimeType,
        size: input.imageSizeBytes,
      });
      if (input.previousImageKey) await this.minioService.deleteObject(input.previousImageKey);
      imageKey = objectName;
    } else if (input.removeImage) {
      if (input.previousImageKey) await this.minioService.deleteObject(input.previousImageKey);
      imageKey = null;
    }

    return this.notificationRepo.update(input.id, {
      ...(input.title !== undefined && { title: input.title }),
      ...(input.body !== undefined && { body: input.body }),
      ...(imageKey !== undefined && { imageKey }),
      ...(input.youtubeUrl !== undefined && { youtubeUrl: input.youtubeUrl }),
    });
  }
}
