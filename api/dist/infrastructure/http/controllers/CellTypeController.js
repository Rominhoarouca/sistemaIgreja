"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CellTypeController = void 0;
const zod_1 = require("zod");
const AppError_1 = require("@shared/errors/AppError");
const createSchema = zod_1.z.object({
    name: zod_1.z.string().min(2),
    description: zod_1.z.string().optional(),
});
const updateSchema = zod_1.z.object({
    name: zod_1.z.string().min(2).optional(),
    description: zod_1.z.string().nullable().optional(),
});
class CellTypeController {
    prisma;
    constructor(prisma) {
        this.prisma = prisma;
    }
    findAll = async (_req, res) => {
        const types = await this.prisma.cellType.findMany({
            orderBy: { name: 'asc' },
        });
        res.json({ cellTypes: types });
    };
    create = async (req, res) => {
        const data = createSchema.parse(req.body);
        const exists = await this.prisma.cellType.findUnique({ where: { name: data.name } });
        if (exists)
            throw new AppError_1.AppError('Já existe um tipo de célula com esse nome', 409);
        const cellType = await this.prisma.cellType.create({ data: { name: data.name, description: data.description ?? null } });
        res.status(201).json({ cellType });
    };
    update = async (req, res) => {
        const { id } = req.params;
        const data = updateSchema.parse(req.body);
        const exists = await this.prisma.cellType.findUnique({ where: { id } });
        if (!exists)
            throw AppError_1.AppError.notFound('Tipo de célula não encontrado');
        if (data.name && data.name !== exists.name) {
            const nameConflict = await this.prisma.cellType.findUnique({ where: { name: data.name } });
            if (nameConflict)
                throw new AppError_1.AppError('Já existe um tipo de célula com esse nome', 409);
        }
        const cellType = await this.prisma.cellType.update({
            where: { id },
            data: {
                ...(data.name !== undefined && { name: data.name }),
                ...(data.description !== undefined && { description: data.description }),
            },
        });
        res.json({ cellType });
    };
    delete = async (req, res) => {
        const { id } = req.params;
        const exists = await this.prisma.cellType.findUnique({ where: { id } });
        if (!exists)
            throw AppError_1.AppError.notFound('Tipo de célula não encontrado');
        await this.prisma.cellType.delete({ where: { id } });
        res.status(204).send();
    };
}
exports.CellTypeController = CellTypeController;
