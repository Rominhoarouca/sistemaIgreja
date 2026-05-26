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
  readonly leaderId: string;
  readonly leaderName?: string;
  readonly address: string;
  readonly neighborhood: string;
  readonly city: string;
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
  readonly leaderId: string;
  readonly address: string;
  readonly neighborhood: string;
  readonly city: string;
  readonly dayOfWeek: DayOfWeek;
  readonly time: string;
  readonly maxCapacity?: number;
  readonly latitude?: number | null;
  readonly longitude?: number | null;
}
