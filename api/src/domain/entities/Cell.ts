export type DayOfWeek =
  | 'segunda'
  | 'terca'
  | 'quarta'
  | 'quinta'
  | 'sexta'
  | 'sabado'
  | 'domingo';

export interface Cell {
  readonly id: string;
  readonly name: string;
  /** Null enquanto a célula não tem líder — ver vínculos pendentes. */
  readonly leaderId: string | null;
  readonly leaderName?: string;
  // Derivados de leader → supervisor → coordenação. Null quando o líder não
  // tem supervisor, ou o supervisor não tem coordenação.
  readonly leaderSupervisorId?: string | null;
  readonly supervisorName?: string | null;
  readonly coordenacaoName?: string | null;
  readonly coordenacaoColor?: string | null;
  readonly cellTypeId: string | null;
  readonly cellTypeName?: string | null;
  readonly address: string;
  readonly bairroId: string | null;
  readonly estadoId?: string | null;
  readonly cidadeId?: string | null;
  // Derived from bairro relation for backward-compat display
  readonly neighborhood: string;
  readonly city: string;
  readonly state: string;
  readonly dayOfWeek: DayOfWeek;
  readonly time: string;
  readonly maxCapacity: number;
  readonly currentCount: number;
  readonly latitude: number | null;
  readonly longitude: number | null;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export interface CellWithDistance extends Cell {
  readonly distanceKm: number;
}

export interface NearbySearchParams {
  readonly latitude: number;
  readonly longitude: number;
  readonly radiusKm: number;
}

export interface CreateCellData {
  readonly name: string;
  readonly leaderId?: string | null;
  readonly cellTypeId?: string | null;
  readonly address: string;
  readonly bairroId?: string | null;
  readonly dayOfWeek: DayOfWeek;
  readonly time: string;
  readonly maxCapacity?: number;
  readonly latitude?: number | null;
  readonly longitude?: number | null;
}
