import type { Child, User, UserProfile, UserWithPassword } from '../entities/User';

export interface UpdateProfileData {
  name?: string;
  phone?: string | null;
  address?: string | null;
  birthDate?: Date | null;
  photoKey?: string;
}

export interface IUserRepository {
  findById(id: string): Promise<User | null>;
  findByEmail(email: string): Promise<UserWithPassword | null>;
  save(user: Omit<UserWithPassword, 'createdAt' | 'updatedAt'>): Promise<User>;
  listLeaders(): Promise<User[]>;
  getProfile(id: string): Promise<UserProfile | null>;
  updateProfile(id: string, data: UpdateProfileData): Promise<User>;
  upsertChildren(userId: string, children: Array<{ id?: string; name: string; birthDate?: Date | null }>): Promise<Child[]>;
}
