import type { PrismaClient } from '@prisma/client';
import type { IUserRepository, UpdateProfileData, CreateUserData } from '@domain/repositories/IUserRepository';
import type { Child, User, UserProfile, UserWithPassword, UserRole } from '@domain/entities/User';
import { effectiveRoles, highestRole } from '@domain/entities/User';

/**
 * Filtro por papel considerando o multi-papel: bate tanto no papel principal
 * (`role`) quanto nos acumulados (`roles`).
 */
function byRole(role: UserRole) {
  return { OR: [{ role }, { roles: { has: role } }] };
}

export class PrismaUserRepository implements IUserRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async findById(id: string): Promise<User | null> {
    const user = await this.prisma.user.findUnique({ where: { id } });
    if (!user) return null;
    const { password: _p, ...rest } = user;
    return { ...rest };
  }

  async findByEmail(email: string): Promise<UserWithPassword | null> {
    // email é único por igreja; o guard multi-tenant injeta church_id quando há
    // contexto. Sem contexto (login público) retorna a 1ª correspondência.
    const user = await this.prisma.user.findFirst({ where: { email } });
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
        roles: effectiveRoles(data),
        ...(data.churchId ? { churchId: data.churchId } : {}),
      },
    });
    const { password: _p, ...rest } = user;
    return { ...rest };
  }

  async createUser(data: CreateUserData): Promise<User> {
    const roles = effectiveRoles({ role: data.role, roles: data.roles ?? [] });
    // O papel principal é o mais privilegiado do conjunto: é ele que decide a
    // home do app e as regras que restringem por papel.
    const primaryRole = highestRole(roles);
    const supervisorId =
      !roles.includes('LIDER') && data.leaderIds?.[0] ? data.leaderIds[0] : undefined;

    const user = await this.prisma.user.create({
      data: {
        name: data.name,
        email: data.email,
        password: data.password,
        role: primaryRole,
        roles,
        ...(data.phone ? { phone: data.phone } : {}),
        ...(data.address ? { address: data.address } : {}),
        ...(supervisorId ? { supervisorId } : {}),
        ...(data.coordenacaoId ? { coordenacaoId: data.coordenacaoId } : {}),
      },
    });

    // Handle cell associations for leaders
    if (roles.includes('LIDER') && data.cellIds && data.cellIds.length > 0) {
      await this.prisma.cell.updateMany({
        where: { id: { in: data.cellIds } },
        data: { leaderId: user.id },
      });
    }

    // Handle leader associations for supervisors
    if (roles.includes('SUPERVISOR') && data.leaderIds && data.leaderIds.length > 0) {
      await this.prisma.user.updateMany({
        where: { id: { in: data.leaderIds } },
        data: { supervisorId: user.id },
      });
    }

    // Handle associations for coordinators
    if (roles.includes('COORDENADOR') && data.coordenacaoId) {
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
      where: byRole('LIDER'),
      orderBy: { name: 'asc' },
    });

    return leaders.map(({ password: _p, ...rest }) => ({ ...rest }));
  }

  async listAll(): Promise<User[]> {
    const users = await this.prisma.user.findMany({ orderBy: { name: 'asc' } });
    return users.map(({ password: _p, ...rest }) => ({ ...rest }));
  }

  async listLeadersWithoutCell(): Promise<User[]> {
    const leaders = await this.prisma.user.findMany({
      where: { ...byRole('LIDER'), cells: { none: {} } },
      orderBy: { name: 'asc' },
    });
    return leaders.map(({ password: _p, ...rest }) => ({ ...rest }));
  }

  async listSupervisors(): Promise<User[]> {
    const supervisors = await this.prisma.user.findMany({
      where: byRole('SUPERVISOR'),
      orderBy: { name: 'asc' },
    });
    return supervisors.map(({ password: _p, ...rest }) => ({ ...rest }));
  }

  async listCoordinadores(): Promise<User[]> {
    const coordinadores = await this.prisma.user.findMany({
      where: byRole('COORDENADOR'),
      orderBy: { name: 'asc' },
    });
    return coordinadores.map(({ password: _p, ...rest }) => ({ ...rest }));
  }

  async searchUsers(query: string): Promise<User[]> {
    const users = await this.prisma.user.findMany({
      where: {
        OR: [
          { name: { contains: query, mode: 'insensitive' } },
          { email: { contains: query, mode: 'insensitive' } },
        ],
      },
      orderBy: { name: 'asc' },
      take: 20,
    });
    return users.map(({ password: _p, ...rest }) => ({ ...rest }));
  }

  async findLeadersBySupervisorId(supervisorId: string): Promise<User[]> {
    const leaders = await this.prisma.user.findMany({
      where: { ...byRole('LIDER'), supervisorId },
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
      where: { ...byRole('SUPERVISOR'), coordenacaoId: coordenacao.id },
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
    // Duas portas de entrada na coordenação: pelo supervisor ou direto. Um
    // coordenador pode ter zero supervisores e ainda assim ter líderes na
    // rede — só o primeiro caso era considerado.
    const leaders = await this.prisma.user.findMany({
      where: {
        AND: [
          byRole('LIDER'),
          {
            OR: [
              { supervisor: { coordenacaoId: coordenacao.id } },
              { supervisorId: null, coordenacaoId: coordenacao.id },
            ],
          },
        ],
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

    return Promise.all(
      children.map((child) =>
        child.id
          ? this.prisma.child.update({
              where: { id: child.id },
              data: { name: child.name, birthDate: child.birthDate ?? null },
            })
          : this.prisma.child.create({
              data: { userId, name: child.name, birthDate: child.birthDate ?? null },
            }),
      ),
    );
  }

  /**
   * Promover soma o novo papel aos que a pessoa já tem — o líder promovido a
   * supervisor continua liderando a célula dele.
   */
  async promoteUser(userId: string, role: UserRole): Promise<void> {
    const current = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { role: true, roles: true },
    });
    if (!current) return;
    const roles = effectiveRoles({ role: current.role, roles: [...current.roles, role] });
    await this.prisma.user.update({
      where: { id: userId },
      data: { role: highestRole(roles), roles },
    });
  }

  /** Define o conjunto completo de papéis do usuário (tela de perfis). */
  async setRoles(userId: string, requested: UserRole[]): Promise<User> {
    const roles = effectiveRoles({ role: highestRole(requested), roles: requested });
    const user = await this.prisma.user.update({
      where: { id: userId },
      data: { role: highestRole(roles), roles },
    });
    const { password: _p, ...rest } = user;
    return { ...rest };
  }

  async assignSupervisorToCoordenacao(supervisorId: string, coordenacaoId: string | null): Promise<void> {
    await this.prisma.user.update({
      where: { id: supervisorId },
      data: { coordenacaoId },
    });
  }
}
