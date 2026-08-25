export interface Notification {
  readonly id: string;
  readonly title: string;
  readonly body: string;
  readonly imageKey: string | null;
  readonly youtubeUrl: string | null;
  readonly createdById: string;
  readonly createdAt: Date;
}

export interface NotificationListItem {
  readonly id: string;
  readonly title: string;
  readonly isRead: boolean;
  readonly createdAt: Date;
}

export interface NotificationDetail {
  readonly id: string;
  readonly title: string;
  readonly body: string;
  readonly imageKey: string | null;
  readonly youtubeUrl: string | null;
  readonly createdAt: Date;
  readonly isRead: boolean;
}

export interface CreateNotificationData {
  readonly title: string;
  readonly body: string;
  readonly imageKey?: string | null;
  readonly youtubeUrl?: string | null;
  readonly createdById: string;
  readonly recipientUserIds: string[];
}

export interface NotificationAdminListItem {
  readonly id: string;
  readonly title: string;
  readonly createdAt: Date;
  readonly recipientCount: number;
}

export interface UpdateNotificationData {
  readonly title?: string;
  readonly body?: string;
  readonly imageKey?: string | null;
  readonly youtubeUrl?: string | null;
}
