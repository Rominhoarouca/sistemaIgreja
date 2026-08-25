import type { Request, Response } from 'express';
import { z } from 'zod';
import type { CreateNotificationUseCase } from '@application/usecases/notification/CreateNotificationUseCase';
import type { UpdateNotificationUseCase } from '@application/usecases/notification/UpdateNotificationUseCase';
import type { INotificationRepository } from '@domain/repositories/INotificationRepository';
import type { MinioService } from '@infrastructure/storage/MinioService';
import { PrismaClient } from '@prisma/client';
import { AppError } from '@shared/errors/AppError';

const groupSchema = z.object({
  type: z.enum([
    'SUPERVISORS',
    'LEADERS',
    'COORDENADORES',
    'CELL_TYPE',
    'COORDENACAO_LEADERS',
    'LEADERS_WITH_CELLS',
    'LEADERS_WITHOUT_CELLS',
  ]),
  cellTypeId: z.string().uuid().optional(),
  coordenacaoId: z.string().uuid().optional(),
});

const createBodySchema = z.object({
  title: z.string().min(1),
  bodyDelta: z.string().min(1),
  youtubeUrl: z.string().url().optional(),
  userIds: z.string().optional(), // JSON encoded array
  groups: z.string().optional(), // JSON encoded array
});

const updateBodySchema = z.object({
  title: z.string().min(1).optional(),
  bodyDelta: z.string().min(1).optional(),
  youtubeUrl: z.string().url().optional(),
  removeImage: z.string().optional(), // 'true' vinda de FormData
});

export class NotificationController {
  constructor(
    private readonly createNotificationUseCase: CreateNotificationUseCase,
    private readonly updateNotificationUseCase: UpdateNotificationUseCase,
    private readonly notificationRepo: INotificationRepository,
    private readonly minioService: MinioService,
    private readonly prisma: PrismaClient,
  ) {}

  create = async (req: Request, res: Response): Promise<void> => {
    const file = req.file;
    const parsed = createBodySchema.parse(req.body);

    let userIds: string[] = [];
    if (parsed.userIds) {
      try {
        const arr = JSON.parse(parsed.userIds);
        if (Array.isArray(arr)) userIds = arr as string[];
      } catch {
        // ignore malformed input, treated as no explicit users
      }
    }

    let groups: z.infer<typeof groupSchema>[] = [];
    if (parsed.groups) {
      try {
        const arr = JSON.parse(parsed.groups);
        if (Array.isArray(arr)) groups = arr.map((g) => groupSchema.parse(g));
      } catch {
        throw new AppError('Público-alvo inválido', 400);
      }
    }

    const recipientIds = await this.resolveAudience(userIds, groups);
    if (recipientIds.length === 0) {
      throw new AppError('Nenhum destinatário informado', 400);
    }

    const notification = await this.createNotificationUseCase.execute({
      title: parsed.title,
      body: parsed.bodyDelta,
      ...(parsed.youtubeUrl !== undefined && { youtubeUrl: parsed.youtubeUrl }),
      createdById: req.userId,
      recipientUserIds: recipientIds,
      ...(file && {
        imageBuffer: file.buffer,
        imageMimeType: file.mimetype,
        imageOriginalName: file.originalname,
        imageSizeBytes: file.size,
      }),
    });

    res.status(201).json({ notification, recipientCount: recipientIds.length });
  };

  listMine = async (req: Request, res: Response): Promise<void> => {
    const notifications = await this.notificationRepo.findForUser(req.userId);
    res.json({ notifications });
  };

  getDetail = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const detail = await this.notificationRepo.findDetailForUser(id, req.userId);
    if (!detail) throw AppError.notFound('Notificação não encontrada');

    const imageUrl = detail.imageKey ? await this.minioService.presignedDownloadUrl(detail.imageKey) : null;
    res.json({
      notification: {
        id: detail.id,
        title: detail.title,
        body: detail.body,
        imageUrl,
        youtubeUrl: detail.youtubeUrl,
        createdAt: detail.createdAt,
        isRead: detail.isRead,
      },
    });
  };

  markRead = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    await this.notificationRepo.markRead(id, req.userId);
    res.status(204).send();
  };

  markAllRead = async (req: Request, res: Response): Promise<void> => {
    await this.notificationRepo.markAllRead(req.userId);
    res.status(204).send();
  };

  listAllForAdmin = async (_req: Request, res: Response): Promise<void> => {
    const notifications = await this.notificationRepo.findAllForAdmin();
    res.json({ notifications });
  };

  getDetailForAdmin = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const notification = await this.notificationRepo.findByIdRaw(id);
    if (!notification) throw AppError.notFound('Notificação não encontrada');

    const imageUrl = notification.imageKey
      ? await this.minioService.presignedDownloadUrl(notification.imageKey)
      : null;
    res.json({
      notification: {
        id: notification.id,
        title: notification.title,
        body: notification.body,
        imageUrl,
        youtubeUrl: notification.youtubeUrl,
        createdAt: notification.createdAt,
      },
    });
  };

  updateForAdmin = async (req: Request, res: Response): Promise<void> => {
    const { id } = req.params as { id: string };
    const existing = await this.notificationRepo.findByIdRaw(id);
    if (!existing) throw AppError.notFound('Notificação não encontrada');

    const file = req.file;
    const parsed = updateBodySchema.parse(req.body);

    const notification = await this.updateNotificationUseCase.execute({
      id,
      ...(parsed.title !== undefined && { title: parsed.title }),
      ...(parsed.bodyDelta !== undefined && { body: parsed.bodyDelta }),
      ...(parsed.youtubeUrl !== undefined && { youtubeUrl: parsed.youtubeUrl }),
      previousImageKey: existing.imageKey,
      removeImage: parsed.removeImage === 'true',
      ...(file && {
        imageBuffer: file.buffer,
        imageMimeType: file.mimetype,
        imageOriginalName: file.originalname,
        imageSizeBytes: file.size,
      }),
    });

    res.json({ notification });
  };

  private async resolveAudience(
    explicitUserIds: string[],
    groups: z.infer<typeof groupSchema>[],
  ): Promise<string[]> {
    const ids = new Set<string>();

    if (explicitUserIds.length > 0) {
      const users = await this.prisma.user.findMany({
        where: { id: { in: explicitUserIds } },
        select: { id: true },
      });
      users.forEach((u) => ids.add(u.id));
    }

    for (const group of groups) {
      switch (group.type) {
        case 'SUPERVISORS': {
          const users = await this.prisma.user.findMany({ where: { role: 'SUPERVISOR' }, select: { id: true } });
          users.forEach((u) => ids.add(u.id));
          break;
        }
        case 'LEADERS': {
          const users = await this.prisma.user.findMany({ where: { role: 'LIDER' }, select: { id: true } });
          users.forEach((u) => ids.add(u.id));
          break;
        }
        case 'COORDENADORES': {
          const users = await this.prisma.user.findMany({ where: { role: 'COORDENADOR' }, select: { id: true } });
          users.forEach((u) => ids.add(u.id));
          break;
        }
        case 'CELL_TYPE': {
          if (!group.cellTypeId) break;
          const cells = await this.prisma.cell.findMany({
            where: { cellTypeId: group.cellTypeId },
            select: { leaderId: true },
            distinct: ['leaderId'],
          });
          cells.forEach((c) => ids.add(c.leaderId));
          break;
        }
        case 'COORDENACAO_LEADERS': {
          if (!group.coordenacaoId) break;
          const users = await this.prisma.user.findMany({
            where: { role: 'LIDER', supervisor: { coordenacaoId: group.coordenacaoId } },
            select: { id: true },
          });
          users.forEach((u) => ids.add(u.id));
          break;
        }
        case 'LEADERS_WITH_CELLS': {
          const users = await this.prisma.user.findMany({
            where: { role: 'LIDER', cells: { some: {} } },
            select: { id: true },
          });
          users.forEach((u) => ids.add(u.id));
          break;
        }
        case 'LEADERS_WITHOUT_CELLS': {
          const users = await this.prisma.user.findMany({
            where: { role: 'LIDER', cells: { none: {} } },
            select: { id: true },
          });
          users.forEach((u) => ids.add(u.id));
          break;
        }
      }
    }

    return Array.from(ids);
  }
}
