import type { PrismaClient } from '@prisma/client';
import type { INotificationRepository } from '@domain/repositories/INotificationRepository';
import type {
  Notification,
  NotificationDetail,
  NotificationListItem,
  NotificationAdminListItem,
  CreateNotificationData,
  UpdateNotificationData,
} from '@domain/entities/Notification';

export class PrismaNotificationRepository implements INotificationRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async create(data: CreateNotificationData): Promise<Notification> {
    return this.prisma.$transaction(async (tx) => {
      const notification = await tx.notification.create({
        data: {
          title: data.title,
          body: data.body,
          imageKey: data.imageKey ?? null,
          youtubeUrl: data.youtubeUrl ?? null,
          createdById: data.createdById,
        },
      });
      await tx.notificationRecipient.createMany({
        data: data.recipientUserIds.map((userId) => ({
          notificationId: notification.id,
          userId,
        })),
      });
      return notification;
    });
  }

  async findForUser(userId: string): Promise<NotificationListItem[]> {
    // Além das recebidas (via NotificationRecipient), inclui as que o próprio
    // usuário criou — sem isso o admin nunca vê a notificação que acabou de
    // enviar, a menos que também tenha se incluído como destinatário.
    const [recipientRows, createdRows] = await Promise.all([
      this.prisma.notificationRecipient.findMany({
        where: { userId },
        select: {
          readAt: true,
          notification: { select: { id: true, title: true, createdAt: true } },
        },
      }),
      this.prisma.notification.findMany({
        where: { createdById: userId },
        select: { id: true, title: true, createdAt: true },
      }),
    ]);

    const byId = new Map<string, NotificationListItem>();
    for (const row of recipientRows) {
      byId.set(row.notification.id, {
        id: row.notification.id,
        title: row.notification.title,
        isRead: row.readAt !== null,
        createdAt: row.notification.createdAt,
      });
    }
    for (const notification of createdRows) {
      if (!byId.has(notification.id)) {
        byId.set(notification.id, {
          id: notification.id,
          title: notification.title,
          isRead: true,
          createdAt: notification.createdAt,
        });
      }
    }

    return Array.from(byId.values()).sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
  }

  async findDetailForUser(notificationId: string, userId: string): Promise<NotificationDetail | null> {
    const recipient = await this.prisma.notificationRecipient.findUnique({
      where: { notificationId_userId: { notificationId, userId } },
      include: { notification: true },
    });

    if (recipient) {
      if (!recipient.readAt) {
        await this.prisma.notificationRecipient.update({
          where: { id: recipient.id },
          data: { readAt: new Date() },
        });
      }
      const { notification } = recipient;
      return {
        id: notification.id,
        title: notification.title,
        body: notification.body,
        imageKey: notification.imageKey,
        youtubeUrl: notification.youtubeUrl,
        createdAt: notification.createdAt,
        isRead: true,
      };
    }

    // Não é destinatário — permite acesso se foi quem criou (ex.: admin
    // revendo o que enviou, sem ter se incluído como alvo).
    const notification = await this.prisma.notification.findFirst({
      where: { id: notificationId, createdById: userId },
    });
    if (!notification) return null;

    return {
      id: notification.id,
      title: notification.title,
      body: notification.body,
      imageKey: notification.imageKey,
      youtubeUrl: notification.youtubeUrl,
      createdAt: notification.createdAt,
      isRead: true,
    };
  }

  async markRead(notificationId: string, userId: string): Promise<void> {
    await this.prisma.notificationRecipient.updateMany({
      where: { notificationId, userId, readAt: null },
      data: { readAt: new Date() },
    });
  }

  async markAllRead(userId: string): Promise<void> {
    await this.prisma.notificationRecipient.updateMany({
      where: { userId, readAt: null },
      data: { readAt: new Date() },
    });
  }

  async findAllForAdmin(): Promise<NotificationAdminListItem[]> {
    const rows = await this.prisma.notification.findMany({
      orderBy: { createdAt: 'desc' },
      include: { _count: { select: { recipients: true } } },
    });
    return rows.map((r) => ({
      id: r.id,
      title: r.title,
      createdAt: r.createdAt,
      recipientCount: r._count.recipients,
    }));
  }

  async findByIdRaw(id: string): Promise<Notification | null> {
    return this.prisma.notification.findUnique({ where: { id } });
  }

  async update(id: string, data: UpdateNotificationData): Promise<Notification> {
    return this.prisma.notification.update({
      where: { id },
      data: {
        ...(data.title !== undefined && { title: data.title }),
        ...(data.body !== undefined && { body: data.body }),
        ...(data.imageKey !== undefined && { imageKey: data.imageKey }),
        ...(data.youtubeUrl !== undefined && { youtubeUrl: data.youtubeUrl }),
      },
    });
  }
}
