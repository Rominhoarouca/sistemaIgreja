import type { Request, Response } from 'express';
import { z } from 'zod';
import type { UploadMaterialUseCase } from '@application/usecases/material/UploadMaterialUseCase';
import type { IMaterialRepository } from '@domain/repositories/IMaterialRepository';
import type { ICellRepository } from '@domain/repositories/ICellRepository';
import type { MinioService } from '@infrastructure/storage/MinioService';
import { AppError } from '@shared/errors/AppError';

export class MaterialController {
  constructor(
    private readonly uploadUseCase: UploadMaterialUseCase,
    private readonly materialRepo: IMaterialRepository,
    private readonly minioService: MinioService,
    private readonly cellRepo: ICellRepository,
  ) {}

  upload = async (req: Request, res: Response): Promise<void> => {
    const file = req.file;
    if (!file) throw new AppError('Nenhum arquivo enviado', 400);

    // Accept either a single cellId, a JSON array 'cellIds' (when sending via multipart/form-data)
    // or the 'allCells' flag. We will create one material per target cell.
    const bodySchema = z.object({
      cellId: z.string().uuid().optional(),
      cellIds: z.string().optional(), // JSON encoded array coming from FormData
      allCells: z.string().optional(), // may arrive as 'true' string from form
    });
    const parsed = bodySchema.parse(req.body);
    const title = (req.body.title as string | undefined) ?? file.originalname;
    const description = req.body.description as string | undefined;

    // resolve target cell ids
    let targetCellIds: string[] = [];
    if (parsed.allCells && parsed.allCells === 'true') {
      const cells = await this.cellRepo.findAll();
      targetCellIds = cells.map((c) => c.id);
    } else if (parsed.cellIds) {
      try {
        const arr = JSON.parse(parsed.cellIds as string);
        if (Array.isArray(arr)) targetCellIds = arr as string[];
      } catch (e) {
        // ignore, will fall back to cellId
      }
    }
    if (targetCellIds.length === 0 && parsed.cellId) {
      targetCellIds = [parsed.cellId];
    }

    if (targetCellIds.length === 0) throw new AppError('Nenhuma célula alvo informada', 400);

    const created: any[] = [];
    for (const cellId of targetCellIds) {
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
      created.push(material);
    }

    // If only one created, keep backward compatibility with previous response
    if (created.length === 1) {
      res.status(201).json({ material: created[0] });
    } else {
      res.status(201).json({ materials: created });
    }
  };

  findByCell = async (req: Request, res: Response): Promise<void> => {
    const { cellId } = z.object({ cellId: z.string().uuid().optional() }).parse(req.query);
    if (cellId) {
      const materials = await this.materialRepo.findByCell(cellId);
      res.json({ materials });
      return;
    }
    // Leader without cellId: return materials for all their cells
    if (req.userRole === 'LIDER') {
      const cells = await this.cellRepo.findByLeaderId(req.userId);
      const allMaterials: any[] = [];
      for (const cell of cells) {
        const mats = await this.materialRepo.findByCell(cell.id);
        allMaterials.push(...mats);
      }
      res.json({ materials: allMaterials });
      return;
    }
    const materials = await this.materialRepo.findAll();
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

