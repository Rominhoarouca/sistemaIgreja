import type { Gender } from '@domain/entities/Gender';

export interface CellMember {
  readonly id: string;
  readonly cellId: string;
  readonly name: string;
  readonly phone: string;
  readonly email: string | null;
  readonly address: string | null;
  readonly bairroId: string | null;
  // Derived from bairro relation for backward-compat display
  readonly neighborhood: string | null;
  readonly city: string | null;
  readonly state: string | null;
  readonly birthDate: Date | null;
  readonly gender: Gender | null;
  readonly maritalStatus: string | null;
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
  readonly bairroId?: string | undefined;
  readonly birthDate?: Date | undefined;
  readonly gender?: Gender | undefined;
  readonly maritalStatus?: string | undefined;
  readonly leaderId?: string | undefined;
}
