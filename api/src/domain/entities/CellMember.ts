import type { Gender } from '@domain/entities/Gender';

/** Papel na célula. `MEMBRO` é o padrão de quem não tem função definida. */
export type CellMemberRole = 'MEMBRO' | 'VICE_LIDER' | 'ANFITRIAO';

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
  readonly isBaptized: boolean;
  readonly roleInCell: CellMemberRole;
  readonly photoKey: string | null;
  /** URL assinada da foto, preenchida na camada HTTP. */
  readonly photoUrl?: string | null;
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
  readonly isBaptized?: boolean | undefined;
  readonly roleInCell?: CellMemberRole | undefined;
  readonly leaderId?: string | undefined;
}

export interface UpdateCellMemberData {
  readonly name?: string | undefined;
  readonly phone?: string | undefined;
  readonly email?: string | null | undefined;
  readonly address?: string | null | undefined;
  readonly bairroId?: string | null | undefined;
  readonly birthDate?: Date | null | undefined;
  readonly gender?: Gender | null | undefined;
  readonly maritalStatus?: string | null | undefined;
  readonly isBaptized?: boolean | undefined;
  readonly roleInCell?: CellMemberRole | undefined;
  readonly photoKey?: string | null | undefined;
}
