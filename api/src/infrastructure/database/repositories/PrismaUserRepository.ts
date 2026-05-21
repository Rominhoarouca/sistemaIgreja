import type { PrismaClient } from '@prisma/client';
import type { IUserRepository, UpdateProfileData } from '@domain/repositories/IUserRepository';
import type { Child, User, UserProfile, UserWithPassword } from '@domain/entities/User';

export class PrismaUserRepository implements IUserRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async findById(id: string): Promise<User | null> {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) return null;
    const { password: _p, ...rest } = user;
    return { ...rest };
  }

  async findByEmail(email: string): Promise<UserWithPassword | null> {
    const user = await this.prisma.user.findUnique({ where: { email } });
    return user ?? null;
  }

  async save(data: Omit<UserWithPassword, 'createdAt' | 'updatedAt'>): Promise<User> {
    const user = await this.prisma.user.create({
      data: {
        id: data.id,
        name: data.name,
        email: data.email,
        password: data.password,
        role: data.role,
      },
    });
    const { password: _p, ...rest } = user;
    return { ...rest };
  }

  async listLeaders(): Promise<User[]> {
    const leaders = await this.prisma.user.findMany({
      where: { role: 'LIDER' },
      orderBy: { name: 'asc' },
    });

    return leaders.map(({ password: _p, ...rest }) => ({ ...rest }));
  }

  async getProfile(id: string): Promise<UserProfile | null> {
    const user = await this.prisma.user.findUnique({
      where: { id },
      include: { children: true },
    });
    if (!user) return null;
    const { password: _p, children, ...rest } = user;
    return { ...rest, children };
  }

  async updateProfile(id: string, data: UpdateProfileData): Promise<User> {
    const user = await this.prisma.user.update({
      where: { id },
      data: {
        ...(data.name !== undefined && { name: data.name }),
        ...(data.phone !== undefined && { phone: data.phone }),
        ...(data.address !== undefined && { address: data.address }),
        ...(data.birthDate !== undefined && { birthDate: data.birthDate }),
        ...(data.photoKey !== undefined && { photoKey: data.photoKey }),
      },
    });
    const { password: _p, ...rest } = user;
    return { ...rest };
  }

  async upsertChildren(
    userId: string,
    children: Array<{ id?: string; name: string; birthDate?: Date | null }>,
  ): Promise<Child[]> {
    // Delete children not in the new list
    const existingIds = children.filter((c) => c.id).map((c) => c.id as string);
    await this.prisma.child.deleteMany({
      where: { userId, id: { notIn: existingIds } },
    });

    const results: Child[] = [];
    for (const child of children) {
      if (child.id) {
        const updated = await this.prisma.child.update({
          where: { id: child.id },
          data: { name: child.name, birthDate: child.birthDate ?? null },
        });
        results.push(updated);
      } else {
        const created = await this.prisma.child.create({
          data: { userId, name: child.name, birthDate: child.birthDate ?? null },
        });
        results.push(created);
      }
    }
    return results;
  }
}
