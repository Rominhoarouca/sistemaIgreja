"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PrismaCellMemberRepository = void 0;
const AppError_1 = require("@shared/errors/AppError");
class PrismaCellMemberRepository {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    async findByCellId(cellId) {
        const rows = await this.prisma.cellMember.findMany({
            where: { cellId },
            orderBy: { createdAt: 'desc' },
        });
        return rows.map((row) => this.mapRow(row));
    }
    async create(data) {
        const row = await this.prisma.cellMember.create({
            data: {
                cellId: data.cellId,
                name: data.name,
                phone: data.phone,
                ...(data.email !== undefined ? { email: data.email } : {}),
                ...(data.address !== undefined ? { address: data.address } : {}),
                ...(data.neighborhood !== undefined ? { neighborhood: data.neighborhood } : {}),
                ...(data.city !== undefined ? { city: data.city } : {}),
                ...(data.leaderId !== undefined ? { leaderId: data.leaderId } : {}),
            },
        });
        return this.mapRow(row);
    }
    async convertVisitorToMember(visitorId, cellId) {
        const visitor = await this.prisma.visitor.findUnique({ where: { id: visitorId } });
        if (!visitor) {
            throw AppError_1.AppError.notFound('Visitante não encontrado');
        }
        const targetCellId = cellId ?? visitor.cellId;
        if (!targetCellId) {
            throw new AppError_1.AppError('Visitante sem célula. Informe uma célula para converter.', 400, 'CELL_REQUIRED');
        }
        const existing = await this.prisma.cellMember.findUnique({
            where: { sourceVisitorId: visitorId },
        });
        if (existing) {
            return this.mapRow(existing);
        }
        const member = await this.prisma.$transaction(async (tx) => {
            const created = await tx.cellMember.create({
                data: {
                    cellId: targetCellId,
                    name: visitor.name,
                    phone: visitor.phone,
                    email: visitor.email,
                    address: visitor.address,
                    neighborhood: visitor.neighborhood,
                    city: visitor.city,
                    leaderId: visitor.leaderId,
                    sourceVisitorId: visitor.id,
                },
            });
            await tx.visitor.update({
                where: { id: visitor.id },
                data: {
                    status: 'integrado',
                    cellId: targetCellId,
                },
            });
            return created;
        });
        return this.mapRow(member);
    }
    mapRow(row) {
        return {
            id: row.id,
            cellId: row.cellId,
            name: row.name,
            phone: row.phone,
            email: row.email,
            address: row.address,
            neighborhood: row.neighborhood,
            city: row.city,
            leaderId: row.leaderId,
            sourceVisitorId: row.sourceVisitorId,
            createdAt: row.createdAt,
            updatedAt: row.updatedAt,
        };
    }
}
exports.PrismaCellMemberRepository = PrismaCellMemberRepository;
