import type { Request, Response } from 'express';
import { z } from 'zod';
import type { UploadMaterialUseCase } from '@application/usecases/material/UploadMaterialUseCase';
import type { IMaterialRepository } from '@domain/repositories/IMaterialRepository';
import type { MinioService } from '@infrastructure/storage/MinioService';
import { AppError } from '@shared/errors/AppError';

export class MaterialController {
  constructor(
    private readonly uploadUseCase: UploadMaterialUseCase,
    private readonly materialRepo: IMaterialRepository,
    private readonly minioService: MinioService,
  ) {}

  upload = async (req: Request, res: Response): Promise<void> => {
    const file = req.file;
    if (!file) throw new AppError('Nenhum arquivo enviado', 400);

    const { cellId } = z.object({ cellId: z.string().uuid() }).parse(req.body);
    const title = (req.body.title as string | undefined) ?? file.originalname;
    const description = req.body.description as string | undefined;

    const material = await this.uploadUseCase.execute({
      cellId,
      title,
      ...(description !== undefined && { description }),
      fileBuffer: file.buffer,
      originalName: file.originalname,
      mimeType: file.mimetype,
      sizeBytes: file.size,
      uploadedById: req.userId,
    });

    res.status(201).json({ material });
  };

  findByCell = async (req: Request, res: Response): Promise<void> => {
    const { cellId } = z.object({ cellId: z.string().uuid().optional() }).parse(req.query);
    const materials = cellId
      ? await this.materialRepo.findByCell(cellId)
      : await this.materialRepo.findAll();
    res.json({ materials });
  };

  getDownloadUrl = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const material = await this.materialRepo.findById(id);
    if (!material) throw AppError.notFound('Material não encontrado');
    const url = await this.minioService.presignedDownloadUrl(material.url);
    res.json({ url, filename: material.title });
  };

  delete = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const material = await this.materialRepo.findById(id);
    if (material) {
      await this.minioService.deleteObject(material.url);
    }
    await this.materialRepo.delete(id);
    res.status(204).send();
  };
}

