"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PrismaCoordenacaoRepository = void 0;
class PrismaCoordenacaoRepository {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    async findAll() {
        const rows = await this.prisma.coordenacao.findMany({
            orderBy: { name: 'asc' },
            include: {
                coordinador: { select: { id: true, name: true } },
                supervisores: { select: { id: true, name: true, email: true } },
            },
        });
        return rows.map((r) => ({
            id: r.id,
            name: r.name,
            color: r.color,
            coordinadorId: r.coordinadorId,
            createdAt: r.createdAt,
            updatedAt: r.updatedAt,
            coordinadorName: r.coordinador.name,
            supervisoresCount: r.supervisores.length,
            supervisores: r.supervisores,
        }));
    }
    async findById(id) {
        const r = await this.prisma.coordenacao.findUnique({ where: { id } });
        return r ?? null;
    }
    async findByCoordinadorId(coordinadorId) {
        const r = await this.prisma.coordenacao.findUnique({ where: { coordinadorId } });
        return r ?? null;
    }
    async create(data) {
        const r = await this.prisma.coordenacao.create({
            data: {
                name: data.name,
                color: data.color,
                coordinadorId: data.coordinadorId,
            },
        });
        return r;
    }
    async update(id, data) {
        const r = await this.prisma.coordenacao.update({
            where: { id },
            data: {
                ...(data.name !== undefined && { name: data.name }),
                ...(data.color !== undefined && { color: data.color }),
            },
        });
        return r;
    }
    async delete(id) {
        // Unlink supervisors first
        await this.prisma.user.updateMany({
            where: { coordenacaoId: id },
            data: { coordenacaoId: null },
        });
        await this.prisma.coordenacao.delete({ where: { id } });
    }
}
exports.PrismaCoordenacaoRepository = PrismaCoordenacaoRepository;
