import type { Child, User, UserProfile, UserWithPassword, UserRole } from '../entities/User';

export interface UpdateProfileData {
  name?: string;
  phone?: string | null;
  address?: string | null;
  birthDate?: Date | null;
  photoKey?: string;
  description?: string | null;
  isMarried?: boolean;
  spouseName?: string | null;
  weddingDate?: Date | null;
}

export interface CreateUserData {
  name: string;
  email: string;
  password: string;
  phone?: string;
  cep?: string;
  address?: string;
  numero?: string;
  complemento?: string;
  bairroId?: string;
  role: UserRole;
  cellIds?: string[];
  leaderIds?: string[];
  supervisorIds?: string[];
  coordenacaoId?: string;
}

export interface IUserRepository {
  findById(id: string): Promise<User | null>;
  findByEmail(email: string): Promise<UserWithPassword | null>;
  save(user: Omit<UserWithPassword, 'createdAt' | 'updatedAt'>): Promise<User>;
  createUser(data: CreateUserData): Promise<User>;
  listLeaders(): Promise<User[]>;
  listSupervisors(): Promise<User[]>;
  listCoordinadores(): Promise<User[]>;
  findLeadersBySupervisorId(supervisorId: string): Promise<User[]>;
  findSupervisorsByCoordinatorId(coordinatorId: string): Promise<User[]>;
  findLeadersByCoordinatorId(coordinatorId: string): Promise<User[]>;
  resetPassword(userId: string, passwordHash: string): Promise<void>;
  assignSupervisor(leaderId: string, supervisorId: string | null): Promise<void>;
  promoteUser(userId: string, role: UserRole): Promise<void>;
  assignSupervisorToCoordenacao(supervisorId: string, coordenacaoId: string | null): Promise<void>;
  updateLeaderDescription(leaderId: string, description: string | null): Promise<void>;
  getProfile(id: string): Promise<UserProfile | null>;
  updateProfile(id: string, data: UpdateProfileData): Promise<User>;
  upsertChildren(userId: string, children: Array<{ id?: string; name: string; birthDate?: Date | null }>): Promise<Child[]>;
}
