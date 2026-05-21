export type UserRole = 'ADMIN' | 'LIDER';

export interface User {
  readonly id: string;
  readonly name: string;
  readonly email: string;
  readonly role: UserRole;
  readonly photoKey: string | null;
  readonly phone: string | null;
  readonly address: string | null;
  readonly birthDate: Date | null;
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
}
