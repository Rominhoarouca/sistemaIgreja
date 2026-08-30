export type UserRole =
  | 'SUPERADMIN'
  | 'ADMIN'
  | 'LIDER'
  | 'SUPERVISOR'
  | 'COORDENADOR'
  // Kids: professor da salinha e responsável pela criança. Não fazem parte da
  // equipe de liderança — `requireStaff` continua barrando os dois.
  | 'KIDS'
  | 'RESPONSAVEL';

export interface User {
  readonly id: string;
  readonly churchId: string | null;
  readonly name: string;
  readonly email: string;
  readonly role: UserRole;
  /** Todos os papéis do usuário (inclui `role`). Ver `effectiveRoles`. */
  readonly roles: UserRole[];
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
  /** Null para criança cadastrada na salinha, sem responsável com conta. */
  readonly userId: string | null;
  readonly name: string;
  readonly birthDate: Date | null;
  readonly createdAt: Date;
}

export interface UserProfile extends User {
  readonly children: Child[];
  readonly coordenacaoName: string | null;
  readonly coordenacaoColor: string | null;
}

/**
 * Precedência de papéis, do mais para o menos privilegiado. Usada para escolher
 * o papel "efetivo" quando o usuário acumula vários: as regras que *restringem*
 * (ex.: "líder só enxerga a própria célula") precisam olhar o papel mais alto,
 * senão um admin que também é líder perderia acesso.
 */
export const ROLE_PRECEDENCE: readonly UserRole[] = [
  'SUPERADMIN',
  'ADMIN',
  'COORDENADOR',
  'SUPERVISOR',
  'LIDER',
  'KIDS',
  'RESPONSAVEL',
];

/** União de `role` + `roles`, sem repetição e na ordem de precedência. */
export function effectiveRoles(user: { role: UserRole; roles?: UserRole[] | null }): UserRole[] {
  const set = new Set<UserRole>([user.role, ...(user.roles ?? [])]);
  return ROLE_PRECEDENCE.filter((r) => set.has(r));
}

/** Papel mais privilegiado entre os que o usuário acumula. */
export function highestRole(roles: readonly UserRole[]): UserRole {
  return ROLE_PRECEDENCE.find((r) => roles.includes(r)) ?? 'LIDER';
}
