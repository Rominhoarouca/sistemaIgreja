import type { Request, Response } from 'express';
import { z } from 'zod';
import type { RegisterVisitorUseCase } from '@application/usecases/visitor/RegisterVisitorUseCase';
import type { GetVisitorsUseCase } from '@application/usecases/visitor/GetVisitorsUseCase';
import type { UpdateVisitorStatusUseCase } from '@application/usecases/visitor/UpdateVisitorStatusUseCase';
import type { IVisitorRepository } from '@domain/repositories/IVisitorRepository';
import type { ICellMemberRepository } from '@domain/repositories/ICellMemberRepository';
import { MinioService, StorageFolder } from '@infrastructure/storage/MinioService';
import { randomUUID } from 'crypto';
import { AppError } from '@shared/errors/AppError';

const genderSchema = z.enum(['MASCULINO', 'FEMININO']);

/** Aceita 'YYYY-MM-DD' (input de data) ou ISO completo. */
const birthDateSchema = z
  .string()
  .datetime({ local: true, offset: true })
  .or(z.string().regex(/^\d{4}-\d{2}-\d{2}$/));

const createSchema = z.object({
  name: z.string().min(2),
  phone: z.string().min(8),
  email: z.string().email().optional(),
  address: z.string().optional(),
  // Antes ausentes aqui: o Zod descartava esses campos em silêncio no
  // POST /visitors usado pelos formulários de líder/admin (self-register já
  // os tinha). Visitor já tem as colunas — só faltava aceitar no schema.
  numero: z.string().optional(),
  complemento: z.string().optional(),
  bairroId: z.string().uuid().optional(),
  originChurch: z.string().optional(),
  birthDate: birthDateSchema.optional(),
  gender: genderSchema.optional(),
  maritalStatus: z.string().optional(),
  leaderId: z.string().uuid().optional(),
  cellId: z.string().uuid().optional(),
  referredById: z.string().uuid().optional(),
});

const selfRegisterSchema = z.object({
  // Identifica a igreja do formulário. O middleware publicTenant já resolveu o
  // slug antes de chegar aqui; fica declarado para não ser descartado em
  // silêncio e para constar no schema público.
  churchSlug: z.string().min(1),
  name: z.string().min(2),
  phone: z.string().min(8),
  address: z.string().min(3),
  numero: z.string().min(1),
  complemento: z.string().optional(),
  bairroId: z.string().uuid(),
  birthDate: birthDateSchema.optional(),
  gender: genderSchema.optional(),
  maritalStatus: z.string().optional(),
  isBaptized: z.boolean().default(false),
  knownPersonName: z.string().optional(),
  interests: z.array(z.string()).default([]),
  cellId: z.string().uuid().optional(),
  customCellName: z.string().optional(),
});

const statusSchema = z.object({
  status: z.enum(['novo', 'em_acompanhamento', 'integrado', 'inativo']),
  leaderId: z.string().uuid().optional(),
  cellId: z.string().uuid().optional(),
});

const assignCellSchema = z.object({
  cellId: z.string().uuid().nullable(),
});

const querySchema = z.object({
  leaderId: z.string().uuid().optional(),
  cellId: z.string().uuid().optional(),
  status: z.enum(['novo', 'em_acompanhamento', 'integrado', 'inativo']).optional(),
  search: z.string().optional(),
  page: z.coerce.number().int().positive().default(1),
  pageSize: z.coerce.number().int().positive().max(100).default(20),
});

const convertSchema = z.object({
  cellId: z.string().uuid().optional(),
});

export class VisitorController {
  constructor(
    private readonly registerUseCase: RegisterVisitorUseCase,
    private readonly getVisitorsUseCase: GetVisitorsUseCase,
    private readonly updateStatusUseCase: UpdateVisitorStatusUseCase,
    private readonly visitorRepo: IVisitorRepository,
    private readonly cellMemberRepo: ICellMemberRepository,
    private readonly minioService: MinioService,
  ) {}

  create = async (req: Request, res: Response): Promise<void> => {
    const data = createSchema.parse(req.body);
    const visitor = await this.registerUseCase.execute({
      ...data,
      birthDate: data.birthDate ? new Date(data.birthDate) : undefined,
    });
    res.status(201).json({ visitor });
  };

  selfRegister = async (req: Request, res: Response): Promise<void> => {
    const data = selfRegisterSchema.parse(req.body);
    const birthDate = data.birthDate ? new Date(data.birthDate) : undefined;
    // Store custom cell name in originChurch when not linked to a known cell
    const originChurch = !data.cellId && data.customCellName ? data.customCellName : undefined;
    const visitor = await this.registerUseCase.execute({
      name: data.name,
      phone: data.phone,
      address: data.address,
      numero: data.numero,
      complemento: data.complemento,
      bairroId: data.bairroId,
      birthDate,
      gender: data.gender,
      maritalStatus: data.maritalStatus,
      isBaptized: data.isBaptized,
      knownPersonName: data.knownPersonName,
      interests: data.interests,
      cellId: data.cellId,
      originChurch,
    });
    res.status(201).json({ visitor });
  };

  findAll = async (req: Request, res: Response): Promise<void> => {
    const filters = querySchema.parse(req.query);
    const result = await this.getVisitorsUseCase.execute(filters);
    res.json(result);
  };

  findById = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const visitor = await this.visitorRepo.findById(id);
    if (!visitor) throw AppError.notFound('Visitante não encontrado');
    res.json({ visitor: { ...visitor, photoUrl: await this.photoUrl(visitor.photoKey) } });
  };

  /** URL assinada da foto. Falha de storage vira `null`, não derruba a leitura. */
  private async photoUrl(photoKey: string | null): Promise<string | null> {
    if (!photoKey) return null;
    return this.minioService.presignedDownloadUrl(photoKey).catch(() => null);
  }

  /** Marca/desmarca o visitante como batizado direto no cadastro. */
  setBaptism = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const { isBaptized } = z.object({ isBaptized: z.boolean() }).parse(req.body);
    const existing = await this.visitorRepo.findById(id);
    if (!existing) throw AppError.notFound('Visitante não encontrado');
    const visitor = await this.visitorRepo.setBaptized(id, isBaptized);
    res.json({ visitor: { ...visitor, photoUrl: await this.photoUrl(visitor.photoKey) } });
  };

  uploadPhoto = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const existing = await this.visitorRepo.findById(id);
    if (!existing) throw AppError.notFound('Visitante não encontrado');
    if (!req.file) throw new AppError('Nenhuma foto enviada', 400, 'NO_FILE');

    const ext = (req.file.originalname.split('.').pop() ?? 'jpg').toLowerCase().slice(0, 5);
    const objectName = MinioService.objectKey(
      StorageFolder.visitors,
      id,
      `${randomUUID()}.${ext}`,
    );

    await this.minioService.uploadFile({
      objectName,
      buffer: req.file.buffer,
      mimeType: req.file.mimetype,
      size: req.file.size,
    });

    const visitor = await this.visitorRepo.updatePhotoKey(id, objectName);
    if (existing.photoKey) await this.minioService.deleteObject(existing.photoKey);

    const photoUrl = await this.minioService.presignedDownloadUrl(objectName);
    res.json({ visitor: { ...visitor, photoUrl }, photoUrl });
  };

  updateStatus = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const data = statusSchema.parse(req.body);
    const visitor = await this.updateStatusUseCase.execute(id, data);
    res.json({ visitor });
  };

  convertToMember = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const { cellId } = convertSchema.parse(req.body ?? {});
    const member = await this.cellMemberRepo.convertVisitorToMember(id, cellId);
    const visitor = await this.visitorRepo.findById(id);
    if (!visitor) throw AppError.notFound('Visitante não encontrado');
    res.json({ member, visitor });
  };

  assignCell = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const { cellId } = assignCellSchema.parse(req.body);
    const visitor = await this.visitorRepo.findById(id);
    if (!visitor) throw AppError.notFound('Visitante não encontrado');
    const updated = await this.visitorRepo.updateStatus(id, {
      status: visitor.status,
      cellId: cellId ?? undefined,
    });
    res.json({ visitor: updated });
  };
}
