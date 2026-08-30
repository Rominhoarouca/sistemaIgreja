import type { IMaterialRepository } from '@domain/repositories/IMaterialRepository';
import type { Material, CreateMaterialData } from '@domain/entities/Material';
import { MinioService, StorageFolder } from '@infrastructure/storage/MinioService';
import { v4 as uuidv4 } from 'uuid';
import path from 'path';

interface UploadMaterialInput {
  cellId: string;
  title: string;
  description?: string;
  fileBuffer: Buffer;
  originalName: string;
  mimeType: string;
  sizeBytes: number;
  uploadedById: string;
}

export class UploadMaterialUseCase {
  constructor(
    private readonly materialRepo: IMaterialRepository,
    private readonly minioService: MinioService,
  ) {}

  async execute(input: UploadMaterialInput): Promise<Material> {
    const ext = path.extname(input.originalName).toLowerCase();
    const objectName = MinioService.objectKey(
      StorageFolder.materials,
      input.cellId,
      `${uuidv4()}${ext}`,
    );

    await this.minioService.uploadFile({
      objectName,
      buffer: input.fileBuffer,
      mimeType: input.mimeType,
      size: input.sizeBytes,
    });

    const fileType = this.resolveFileType(ext, input.mimeType);

    const data: CreateMaterialData = {
      cellId: input.cellId,
      title: input.title,
      ...(input.description !== undefined && { description: input.description }),
      url: objectName, // stored as MinIO object key
      fileType,
      sizeBytes: input.sizeBytes,
      uploadedById: input.uploadedById,
    };

    return this.materialRepo.create(data);
  }

  private resolveFileType(ext: string, mime: string): CreateMaterialData['fileType'] {
    if (ext === '.pdf' || mime === 'application/pdf') return 'pdf';
    if (['.doc', '.docx'].includes(ext)) return 'docx';
    if (['.ppt', '.pptx'].includes(ext)) return 'ppt';
    if (mime.startsWith('video/')) return 'video';
    return 'outro';
  }
}
