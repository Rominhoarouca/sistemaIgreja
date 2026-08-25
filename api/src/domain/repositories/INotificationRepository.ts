import type {
  Notification,
  NotificationDetail,
  NotificationListItem,
  NotificationAdminListItem,
  CreateNotificationData,
  UpdateNotificationData,
} from '../entities/Notification';

export interface INotificationRepository {
  create(data: CreateNotificationData): Promise<Notification>;
  findForUser(userId: string): Promise<NotificationListItem[]>;
  findDetailForUser(notificationId: string, userId: string): Promise<NotificationDetail | null>;
  markRead(notificationId: string, userId: string): Promise<void>;
  markAllRead(userId: string): Promise<void>;
  findAllForAdmin(): Promise<NotificationAdminListItem[]>;
  findByIdRaw(id: string): Promise<Notification | null>;
  update(id: string, data: UpdateNotificationData): Promise<Notification>;
}
