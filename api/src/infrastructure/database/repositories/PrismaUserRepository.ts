import type { PrismaClient } from '@prisma/client';
import type { IUserRepository, UpdateProfileData, CreateUserData } from '@domain/repositories/IUserRepository';
import type { Child, User, UserProfile, UserWithPassword, UserRole } from '@domain/entities/User';

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

  async createUser(data: CreateUserData): Promise<User> {
    const supervisorId =
      data.role !== 'LIDER' && data.leaderIds?.[0] ? data.leaderIds[0] : undefined;

    const user = await this.prisma.user.create({
      data: {
        name: data.name,
        email: data.email,
        password: data.password,
        role: data.role,
        ...(data.phone ? { phone: data.phone } : {}),
        ...(data.address ? { address: data.address } : {}),
        ...(supervisorId ? { supervisorId } : {}),
        ...(data.coordenacaoId ? { coordenacaoId: data.coordenacaoId } : {}),
      },
    });

    // Handle cell associations for leaders
    if (data.role === 'LIDER' && data.cellIds && data.cellIds.length > 0) {
      await this.prisma.cell.updateMany({
        where: { id: { in: data.cellIds } },
        data: { leaderId: user.id },
      });
    }

    // Handle leader associations for supervisors
    if (data.role === 'SUPERVISOR' && data.leaderIds && data.leaderIds.length > 0) {
      await this.prisma.user.updateMany({
        where: { id: { in: data.leaderIds } },
        data: { supervisorId: user.id },
      });
    }

    // Handle associations for coordinators
    if (data.role === 'COORDENADOR' && data.coordenacaoId) {
      if (data.leaderIds && data.leaderIds.length > 0) {
        await this.prisma.user.updateMany({
          where: { id: { in: data.leaderIds } },
          data: { coordenacaoId: data.coordenacaoId },
        });
      }

      if (data.supervisorIds && data.supervisorIds.length > 0) {
        await this.prisma.user.updateMany({
          where: { id: { in: data.supervisorIds } },
          data: { coordenacaoId: data.coordenacaoId },
        });
      }
    }

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

  async listSupervisors(): Promise<User[]> {
    const supervisors = await this.prisma.user.findMany({
      where: { role: 'SUPERVISOR' },
      orderBy: { name: 'asc' },
    });
    return supervisors.map(({ password: _p, ...rest }) => ({ ...rest }));
  }

  async listCoordinadores(): Promise<User[]> {
    const coordinadores = await this.prisma.user.findMany({
      where: { role: 'COORDENADOR' },
      orderBy: { name: 'asc' },
    });
    return coordinadores.map(({ password: _p, ...rest }) => ({ ...rest }));
  }

  async findLeadersBySupervisorId(supervisorId: string): Promise<User[]> {
    const leaders = await this.prisma.user.findMany({
      where: { role: 'LIDER', supervisorId },
      orderBy: { name: 'asc' },
    });
    return leaders.map(({ password: _p, ...rest }) => ({ ...rest }));
  }

  async findSupervisorsByCoordinatorId(coordinatorId: string): Promise<User[]> {
    const coordenacao = await this.prisma.coordenacao.findUnique({
      where: { coordinadorId: coordinatorId },
      select: { id: true },
    });
    if (!coordenacao) return [];
    const supervisors = await this.prisma.user.findMany({
      where: { role: 'SUPERVISOR', coordenacaoId: coordenacao.id },
      orderBy: { name: 'asc' },
    });
    return supervisors.map(({ password: _p, ...rest }) => ({ ...rest }));
  }

  async findLeadersByCoordinatorId(coordinatorId: string): Promise<User[]> {
    const coordenacao = await this.prisma.coordenacao.findUnique({
      where: { coordinadorId: coordinatorId },
      select: { id: true },
    });
    if (!coordenacao) return [];
    const leaders = await this.prisma.user.findMany({
      where: {
        role: 'LIDER',
        supervisor: { coordenacaoId: coordenacao.id },
      },
      orderBy: { name: 'asc' },
    });
    return leaders.map(({ password: _p, ...rest }) => ({ ...rest }));
  }

  async resetPassword(userId: string, passwordHash: string): Promise<void> {
    await this.prisma.$transaction([
      this.prisma.user.update({
        where: { id: userId },
        data: { password: passwordHash },
      }),
      // Invalida sessões existentes do usuário-alvo
      this.prisma.refreshToken.deleteMany({ where: { userId } }),
    ]);
  }

  async assignSupervisor(leaderId: string, supervisorId: string | null): Promise<void> {
    await this.prisma.user.update({
      where: { id: leaderId },
      data: { supervisorId },
    });
  }

  async updateLeaderDescription(leaderId: string, description: string | null): Promise<void> {
    await this.prisma.user.update({
      where: { id: leaderId },
      data: { description },
    });
  }

  async getProfile(id: string): Promise<UserProfile | null> {
    const user = await this.prisma.user.findUnique({
      where: { id },
      include: {
        children: true,
        supervisor: { include: { coordenacao: true } },
      },
    });
    if (!user) return null;
    const { password: _p, children, supervisor, ...rest } = user;
    return {
      ...rest,
      children,
      coordenacaoName: supervisor?.coordenacao?.name ?? null,
      coordenacaoColor: supervisor?.coordenacao?.color ?? null,
    };
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
        ...(data.isMarried !== undefined && { isMarried: data.isMarried }),
        ...(data.spouseName !== undefined && { spouseName: data.spouseName }),
        ...(data.weddingDate !== undefined && { weddingDate: data.weddingDate }),
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

  async promoteUser(userId: string, role: UserRole): Promise<void> {
    await this.prisma.user.update({
      where: { id: userId },
      data: { role },
    });
  }

  async assignSupervisorToCoordenacao(supervisorId: string, coordenacaoId: string | null): Promise<void> {
    await this.prisma.user.update({
      where: { id: supervisorId },
      data: { coordenacaoId },
    });
  }
}
