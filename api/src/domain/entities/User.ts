export type UserRole = 'SUPERADMIN' | 'ADMIN' | 'LIDER' | 'SUPERVISOR' | 'COORDENADOR';

export interface User {
  readonly id: string;
  readonly churchId: string | null;
  readonly name: string;
  readonly email: string;
  readonly role: UserRole;
  readonly photoKey: string | null;
  readonly phone: string | null;
  readonly address: string | null;
  readonly birthDate: Date | null;
  readonly isMarried: boolean;
  readonly spouseName: string | null;
  readonly weddingDate: Date | null;
  readonly supervisorId: string | null;
  readonly coordenacaoId: string | null;
  readonly description: string | null;
  readonly createdAt: Date;
  readonly updatedAt: Date;
}

export interface UserWithPassword extends User {
  readonly password: string;
}

export interface Child {
  readonly id: string;
  readonly userId: string;
  readonly name: string;
  readonly birthDate: Date | null;
  readonly createdAt: Date;
}

export interface UserProfile extends User {
  readonly children: Child[];
  readonly coordenacaoName: string | null;
  readonly coordenacaoColor: string | null;
}
