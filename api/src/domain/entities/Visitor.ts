export type VisitorStatus = 'novo' | 'em_acompanhamento' | 'integrado' | 'inativo';

export interface Visitor {
  readonly id: string;
  readonly name: string;
  readonly phone: string;
  readonly email: string | null;
  readonly address: string | null;
  readonly neighborhood: string | null;
  readonly city: string | null;
  readonly originChurch: string | null;
  readonly status: VisitorStatus;
  readonly leaderId: string | null;
  readonly cellId: string | null;
  readonly referredById: string | null;
  readonly memberId: string | null;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export interface CreateVisitorData {
  readonly name: string;
  readonly phone: string;
  readonly email?: string | undefined;
  readonly address?: string | undefined;
  readonly neighborhood?: string | undefined;
  readonly city?: string | undefined;
  readonly originChurch?: string | undefined;
  readonly leaderId?: string | undefined;
  readonly cellId?: string | undefined;
  readonly referredById?: string | undefined;
}

export interface UpdateVisitorStatusData {
  readonly status: VisitorStatus;
  readonly leaderId?: string | undefined;
  readonly cellId?: string | undefined;
}

export interface VisitorFilters {
  readonly leaderId?: string | undefined;
  readonly cellId?: string | undefined;
  readonly status?: VisitorStatus | undefined;
  readonly search?: string | undefined;
  readonly page?: number | undefined;
  readonly pageSize?: number | undefined;
}

export interface PaginatedVisitors {
  readonly data: Visitor[];
  readonly total: number;
  readonly page: number;
  readonly pageSize: number;
  readonly totalPages: number;
}
