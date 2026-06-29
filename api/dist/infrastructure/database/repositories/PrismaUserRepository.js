"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PrismaUserRepository = void 0;
class PrismaUserRepository {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    async findById(id) {
        const user = await this.prisma.user.findUnique({ where: { id } });
        if (!user)
            return null;
        const { password: _p, ...rest } = user;
        return { ...rest };
    }
    async findByEmail(email) {
        const user = await this.prisma.user.findUnique({ where: { email } });
        return user ?? null;
    }
    async save(data) {
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
    async createUser(data) {
        const user = await this.prisma.user.create({
            data: {
                name: data.name,
                email: data.email,
                password: data.password,
                role: data.role,
            },
        });
        const { password: _p, ...rest } = user;
        return { ...rest };
    }
    async listLeaders() {
        const leaders = await this.prisma.user.findMany({
            where: { role: 'LIDER' },
            orderBy: { name: 'asc' },
        });
        return leaders.map(({ password: _p, ...rest }) => ({ ...rest }));
    }
    async listSupervisors() {
        const supervisors = await this.prisma.user.findMany({
            where: { role: 'SUPERVISOR' },
            orderBy: { name: 'asc' },
        });
        return supervisors.map(({ password: _p, ...rest }) => ({ ...rest }));
    }
    async listCoordinadores() {
        const coordinadores = await this.prisma.user.findMany({
            where: { role: 'COORDENADOR' },
            orderBy: { name: 'asc' },
        });
        return coordinadores.map(({ password: _p, ...rest }) => ({ ...rest }));
    }
    async findLeadersBySupervisorId(supervisorId) {
        const leaders = await this.prisma.user.findMany({
            where: { role: 'LIDER', supervisorId },
            orderBy: { name: 'asc' },
        });
        return leaders.map(({ password: _p, ...rest }) => ({ ...rest }));
    }
    async assignSupervisor(leaderId, supervisorId) {
        await this.prisma.user.update({
            where: { id: leaderId },
            data: { supervisorId },
        });
    }
    async updateLeaderDescription(leaderId, description) {
        await this.prisma.user.update({
            where: { id: leaderId },
            data: { description },
        });
    }
    async getProfile(id) {
        const user = await this.prisma.user.findUnique({
            where: { id },
            include: {
                children: true,
                supervisor: { include: { coordenacao: true } },
            },
        });
        if (!user)
            return null;
        const { password: _p, children, supervisor, ...rest } = user;
        return {
            ...rest,
            children,
            coordenacaoName: supervisor?.coordenacao?.name ?? null,
            coordenacaoColor: supervisor?.coordenacao?.color ?? null,
        };
    }
    async updateProfile(id, data) {
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
    async upsertChildren(userId, children) {
        // Delete children not in the new list
        const existingIds = children.filter((c) => c.id).map((c) => c.id);
        await this.prisma.child.deleteMany({
            where: { userId, id: { notIn: existingIds } },
        });
        const results = [];
        for (const child of children) {
            if (child.id) {
                const updated = await this.prisma.child.update({
                    where: { id: child.id },
                    data: { name: child.name, birthDate: child.birthDate ?? null },
                });
                results.push(updated);
            }
            else {
                const created = await this.prisma.child.create({
                    data: { userId, name: child.name, birthDate: child.birthDate ?? null },
                });
                results.push(created);
            }
        }
        return results;
    }
    async promoteUser(userId, role) {
        await this.prisma.user.update({
            where: { id: userId },
            data: { role },
        });
    }
    async assignSupervisorToCoordenacao(supervisorId, coordenacaoId) {
        await this.prisma.user.update({
            where: { id: supervisorId },
            data: { coordenacaoId },
        });
    }
}
exports.PrismaUserRepository = PrismaUserRepository;
