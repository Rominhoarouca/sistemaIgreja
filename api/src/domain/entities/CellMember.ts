export interface CellMember {
  readonly id: string;
  readonly cellId: string;
  readonly name: string;
  readonly phone: string;
  readonly email: string | null;
  readonly address: string | null;
  readonly neighborhood: string | null;
  readonly city: string | null;
  readonly leaderId: string | null;
  readonly sourceVisitorId: string | null;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export interface CreateCellMemberData {
  readonly cellId: string;
  readonly name: string;
  readonly phone: string;
  readonly email?: string | undefined;
  readonly address?: string | undefined;
  readonly neighborhood?: string | undefined;
  readonly city?: string | undefined;
  readonly leaderId?: string | undefined;
}
