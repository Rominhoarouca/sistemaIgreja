import type { INotificationRepository } from '@domain/repositories/INotificationRepository';
import type { Notification, CreateNotificationData } from '@domain/entities/Notification';
import { MinioService, StorageFolder } from '@infrastructure/storage/MinioService';
import { v4 as uuidv4 } from 'uuid';
import path from 'path';

interface CreateNotificationInput {
  title: string;
  body: string;
  youtubeUrl?: string;
  createdById: string;
  recipientUserIds: string[];
  imageBuffer?: Buffer;
  imageMimeType?: string;
  imageOriginalName?: string;
  imageSizeBytes?: number;
}

export class CreateNotificationUseCase {
  constructor(
    private readonly notificationRepo: INotificationRepository,
    private readonly minioService: MinioService,
  ) {}

  async execute(input: CreateNotificationInput): Promise<Notification> {
    let imageKey: string | null = null;

    if (input.imageBuffer && input.imageMimeType && input.imageOriginalName && input.imageSizeBytes) {
      const ext = path.extname(input.imageOriginalName).toLowerCase();
      const objectName = MinioService.objectKey(
        StorageFolder.notifications,
        `${uuidv4()}${ext}`,
      );
      await this.minioService.uploadFile({
        objectName,
        buffer: input.imageBuffer,
        mimeType: input.imageMimeType,
        size: input.imageSizeBytes,
      });
      imageKey = objectName;
    }

    const data: CreateNotificationData = {
      title: input.title,
      body: input.body,
      imageKey,
      ...(input.youtubeUrl !== undefined && { youtubeUrl: input.youtubeUrl }),
      createdById: input.createdById,
      recipientUserIds: input.recipientUserIds,
    };

    return this.notificationRepo.create(data);
  }
}
