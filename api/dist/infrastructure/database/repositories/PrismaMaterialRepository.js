"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.PrismaMaterialRepository = void 0;
class PrismaMaterialRepository {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    async findById(id) {
        return this.prisma.material.findUnique({ where: { id } });
    }
    async findByCell(cellId) {
        return this.prisma.material.findMany({
            where: { cellId },
            orderBy: { uploadedAt: 'desc' },
        });
    }
    async findAll() {
        return this.prisma.material.findMany({
            orderBy: { uploadedAt: 'desc' },
        });
    }
    async create(data) {
        return this.prisma.material.create({
            data: {
                cellId: data.cellId,
                title: data.title,
                description: data.description ?? null,
                url: data.url,
                fileType: data.fileType,
                sizeBytes: data.sizeBytes,
                uploadedById: data.uploadedById,
            },
        });
    }
    async delete(id) {
        await this.prisma.material.delete({ where: { id } });
    }
}
exports.PrismaMaterialRepository = PrismaMaterialRepository;
