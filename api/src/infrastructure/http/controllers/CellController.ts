import type { Request, Response } from 'express';
import { z } from 'zod';
import type { GetNearbyCellsUseCase } from '@application/usecases/cell/GetNearbyCellsUseCase';
import type { ICellRepository } from '@domain/repositories/ICellRepository';
import type { ICellMemberRepository } from '@domain/repositories/ICellMemberRepository';
import type { IUserRepository } from '@domain/repositories/IUserRepository';
import { MinioService, StorageFolder, type StorageFolderName } from '@infrastructure/storage/MinioService';
import { randomUUID } from 'crypto';
import { AppError } from '@shared/errors/AppError';

const nearbySchema = z.object({
  lat: z.coerce.number().min(-90).max(90),
  lng: z.coerce.number().min(-180).max(180),
  radius: z.coerce.number().positive().max(100).default(10),
});

const createCellSchema = z.object({
  name: z.string().min(2),
  // Opcional: numa base zerada a primeira célula é criada antes de existir
  // líder. O vínculo é feito depois, na tela de vínculos pendentes.
  leaderId: z.string().uuid().nullable().optional(),
  cellTypeId: z.string().uuid().optional(),
  address: z.string().min(3),
  bairroId: z.string().uuid().optional(),
  dayOfWeek: z.enum(['segunda', 'terca', 'quarta', 'quinta', 'sexta', 'sabado', 'domingo']),
  time: z.string().regex(/^\d{2}:\d{2}$/, 'Horário deve ser HH:MM'),
  maxCapacity: z.coerce.number().int().positive().optional(),
  latitude: z.coerce.number().optional(),
  longitude: z.coerce.number().optional(),
});

const updateCellSchema = z.object({
  name: z.string().min(2).optional(),
  leaderId: z.string().uuid().nullable().optional(),
  cellTypeId: z.string().uuid().nullable().optional(),
  address: z.string().min(3).optional(),
  bairroId: z.string().uuid().nullable().optional(),
  dayOfWeek: z.enum(['segunda', 'terca', 'quarta', 'quinta', 'sexta', 'sabado', 'domingo']).optional(),
  time: z.string().regex(/^\d{2}:\d{2}$/, 'Horário deve ser HH:MM').optional(),
  maxCapacity: z.coerce.number().int().nonnegative().optional(),
  latitude: z.coerce.number().nullable().optional(),
  longitude: z.coerce.number().nullable().optional(),
});

const cellRoleEnum = z.enum(['MEMBRO', 'VICE_LIDER', 'ANFITRIAO']);

const updateMemberSchema = z.object({
  name: z.string().min(2).optional(),
  phone: z.string().min(8).optional(),
  email: z.string().email().nullable().optional(),
  address: z.string().nullable().optional(),
  bairroId: z.string().uuid().nullable().optional(),
  birthDate: z
    .string()
    .datetime({ local: true, offset: true })
    .or(z.string().regex(/^\d{4}-\d{2}-\d{2}$/))
    .nullable()
    .optional(),
  gender: z.enum(['MASCULINO', 'FEMININO']).nullable().optional(),
  maritalStatus: z.string().nullable().optional(),
  isBaptized: z.boolean().optional(),
  roleInCell: cellRoleEnum.optional(),
});

const createMemberSchema = z.object({
  name: z.string().min(2),
  phone: z.string().min(8),
  email: z.string().email().optional(),
  address: z.string().optional(),
  bairroId: z.string().uuid().optional(),
  // Aceita 'YYYY-MM-DD' (input de data) ou ISO completo.
  birthDate: z
    .string()
    .datetime({ local: true, offset: true })
    .or(z.string().regex(/^\d{4}-\d{2}-\d{2}$/))
    .optional(),
  gender: z.enum(['MASCULINO', 'FEMININO']).optional(),
  maritalStatus: z.string().optional(),
  isBaptized: z.boolean().optional(),
  roleInCell: cellRoleEnum.optional(),
  leaderId: z.string().uuid().optional(),
});

/**
 * Nome do objeto no bucket. A extensão vem do arquivo enviado; o UUID evita
 * colisão e invalida cache da URL assinada anterior.
 */
function photoObjectName(
  folder: StorageFolderName,
  ownerId: string,
  originalName: string,
): string {
  const ext = (originalName.split('.').pop() ?? 'jpg').toLowerCase().slice(0, 5);
  return MinioService.objectKey(folder, ownerId, `${randomUUID()}.${ext}`);
}

export class CellController {
  constructor(
    private readonly getNearbyCellsUseCase: GetNearbyCellsUseCase,
    private readonly cellRepo: ICellRepository,
    private readonly cellMemberRepo: ICellMemberRepository,
    private readonly userRepo: IUserRepository,
    private readonly minioService: MinioService,
  ) {}

  findNearby = async (req: Request, res: Response): Promise<void> => {
    const { lat, lng, radius } = nearbySchema.parse(req.query);
    const cells = await this.getNearbyCellsUseCase.execute({
      latitude: lat,
      longitude: lng,
      radiusKm: radius,
    });
    res.json({ cells });
  };

  findAll = async (_req: Request, res: Response): Promise<void> => {
    const cells = await this.cellRepo.findAll();
    res.json({ cells });
  };

  /**
   * Vínculos pendentes: células sem líder e líderes sem célula. As duas pontas
   * na mesma resposta porque a tela mostra as duas lado a lado.
   */
  findPendingLinks = async (_req: Request, res: Response): Promise<void> => {
    const [cells, leaders] = await Promise.all([
      this.cellRepo.findWithoutLeader(),
      this.userRepo.listLeadersWithoutCell(),
    ]);
    res.json({ cellsWithoutLeader: cells, leadersWithoutCell: leaders });
  };

  findById = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const cell = await this.cellRepo.findById(id);
    if (!cell) throw AppError.notFound('Célula não encontrada');
    res.json({ cell });
  };

  create = async (req: Request, res: Response): Promise<void> => {
    const data = createCellSchema.parse(req.body);
    const createData = {
      name: data.name,
      leaderId: data.leaderId ?? null,
      cellTypeId: data.cellTypeId ?? null,
      address: data.address,
      bairroId: data.bairroId ?? null,
      dayOfWeek: data.dayOfWeek,
      time: data.time,
      ...(data.maxCapacity !== undefined && { maxCapacity: data.maxCapacity }),
      ...(data.latitude !== undefined && { latitude: data.latitude }),
      ...(data.longitude !== undefined && { longitude: data.longitude }),
    };
    const cell = await this.cellRepo.create(createData);
    res.status(201).json({ cell });
  };

  update = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const data = updateCellSchema.parse(req.body);
    const exists = await this.cellRepo.findById(id);
    if (!exists) throw AppError.notFound('Célula não encontrada');
    const updateData = {
      ...(data.name !== undefined && { name: data.name }),
      ...(data.leaderId !== undefined && { leaderId: data.leaderId }),
      ...(data.cellTypeId !== undefined && { cellTypeId: data.cellTypeId }),
      ...(data.address !== undefined && { address: data.address }),
      ...(data.bairroId !== undefined && { bairroId: data.bairroId }),
      ...(data.dayOfWeek !== undefined && { dayOfWeek: data.dayOfWeek }),
      ...(data.time !== undefined && { time: data.time }),
      ...(data.maxCapacity !== undefined && { maxCapacity: data.maxCapacity }),
      ...(data.latitude !== undefined && { latitude: data.latitude }),
      ...(data.longitude !== undefined && { longitude: data.longitude }),
    };
    const cell = await this.cellRepo.update(id, updateData);
    res.json({ cell });
  };

  delete = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const exists = await this.cellRepo.findById(id);
    if (!exists) throw AppError.notFound('Célula não encontrada');
    await this.cellRepo.delete(id);
    res.status(204).send();
  };

  listMembers = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const cell = await this.cellRepo.findById(id);
    if (!cell) throw AppError.notFound('Célula não encontrada');
    const members = await this.cellMemberRepo.findByCellId(id);
    res.json({ members: await this.withPhotoUrls(members) });
  };

  /** Anexa a URL assinada da foto. Falha de storage não derruba a listagem. */
  private async withPhotoUrls<T extends { photoKey: string | null }>(
    rows: T[],
  ): Promise<Array<T & { photoUrl: string | null }>> {
    return Promise.all(
      rows.map(async (row) => ({
        ...row,
        photoUrl: row.photoKey
          ? await this.minioService.presignedDownloadUrl(row.photoKey).catch(() => null)
          : null,
      })),
    );
  }

  updateMember = async (req: Request, res: Response): Promise<void> => {
    const { memberId } = req.params as { memberId: string };
    const existing = await this.cellMemberRepo.findById(memberId);
    if (!existing) throw AppError.notFound('Membro não encontrado');

    const { birthDate, ...data } = updateMemberSchema.parse(req.body);
    const member = await this.cellMemberRepo.update(memberId, {
      ...data,
      ...(birthDate !== undefined
        ? { birthDate: birthDate ? new Date(birthDate) : null }
        : {}),
    });
    const [withUrl] = await this.withPhotoUrls([member]);
    res.json({ member: withUrl });
  };

  deleteMember = async (req: Request, res: Response): Promise<void> => {
    const { memberId } = req.params as { memberId: string };
    const existing = await this.cellMemberRepo.findById(memberId);
    if (!existing) throw AppError.notFound('Membro não encontrado');
    await this.cellMemberRepo.delete(memberId);
    res.status(204).send();
  };

  uploadMemberPhoto = async (req: Request, res: Response): Promise<void> => {
    const { memberId } = req.params as { memberId: string };
    const existing = await this.cellMemberRepo.findById(memberId);
    if (!existing) throw AppError.notFound('Membro não encontrado');
    if (!req.file) throw new AppError('Nenhuma foto enviada', 400, 'NO_FILE');

    const objectName = photoObjectName(StorageFolder.members, memberId, req.file.originalname);
    await this.minioService.uploadFile({
      objectName,
      buffer: req.file.buffer,
      mimeType: req.file.mimetype,
      size: req.file.size,
    });

    const member = await this.cellMemberRepo.update(memberId, { photoKey: objectName });
    // Best-effort: a foto antiga vira lixo no bucket se a remoção falhar.
    if (existing.photoKey) await this.minioService.deleteObject(existing.photoKey);

    const photoUrl = await this.minioService.presignedDownloadUrl(objectName);
    res.json({ member: { ...member, photoUrl }, photoUrl });
  };

  addMember = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const cell = await this.cellRepo.findById(id);
    if (!cell) throw AppError.notFound('Célula não encontrada');

    const data = createMemberSchema.parse(req.body);
    const member = await this.cellMemberRepo.create({
      cellId: id,
      name: data.name,
      phone: data.phone,
      ...(data.email !== undefined ? { email: data.email } : {}),
      ...(data.address !== undefined ? { address: data.address } : {}),
      ...(data.bairroId !== undefined ? { bairroId: data.bairroId } : {}),
      ...(data.birthDate !== undefined ? { birthDate: new Date(data.birthDate) } : {}),
      ...(data.gender !== undefined ? { gender: data.gender } : {}),
      ...(data.maritalStatus !== undefined ? { maritalStatus: data.maritalStatus } : {}),
      ...(data.isBaptized !== undefined ? { isBaptized: data.isBaptized } : {}),
      ...(data.roleInCell !== undefined ? { roleInCell: data.roleInCell } : {}),
      ...(data.leaderId !== undefined ? { leaderId: data.leaderId } : {}),
    });

    res.status(201).json({ member });
  };

  findByLeader = async (req: Request, res: Response): Promise<void> => {
    const cells = await this.cellRepo.findByLeaderId(req.userId);
    res.json({ cells });
  };
}
