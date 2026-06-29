"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CoordenacaoController = void 0;
const zod_1 = require("zod");
const AppError_1 = require("@shared/errors/AppError");
const createSchema = zod_1.z.object({
    name: zod_1.z.string().min(1).max(100),
    color: zod_1.z.string().regex(/^#[0-9a-fA-F]{6}$/, 'Cor deve ser um hex válido (#RRGGBB)'),
    coordinadorId: zod_1.z.string().uuid(),
});
const updateSchema = zod_1.z.object({
    name: zod_1.z.string().min(1).max(100).optional(),
    color: zod_1.z.string().regex(/^#[0-9a-fA-F]{6}$/, 'Cor deve ser um hex válido (#RRGGBB)').optional(),
});
class CoordenacaoController {
    coordenacaoRepo;
    userRepo;
    constructor(coordenacaoRepo, userRepo) {
        this.coordenacaoRepo = coordenacaoRepo;
        this.userRepo = userRepo;
    }
    listAll = async (_req, res) => {
        const coordenacoes = await this.coordenacaoRepo.findAll();
        res.json({ coordenacoes });
    };
    create = async (req, res) => {
        const body = createSchema.parse(req.body);
        const coordinador = await this.userRepo.findById(body.coordinadorId);
        if (!coordinador)
            throw AppError_1.AppError.notFound('Usuário não encontrado');
        if (coordinador.role !== 'COORDENADOR') {
            throw new AppError_1.AppError('O usuário informado não possui o cargo de coordenador', 422, 'INVALID_ROLE');
        }
        const existing = await this.coordenacaoRepo.findByCoordinadorId(body.coordinadorId);
        if (existing) {
            throw AppError_1.AppError.conflict('Este coordenador já possui uma coordenação vinculada');
        }
        const coordenacao = await this.coordenacaoRepo.create(body);
        res.status(201).json({ coordenacao });
    };
    update = async (req, res) => {
        const { id } = req.params;
        const body = updateSchema.parse(req.body);
        const existing = await this.coordenacaoRepo.findById(id);
        if (!existing)
            throw AppError_1.AppError.notFound('Coordenação não encontrada');
        const coordenacao = await this.coordenacaoRepo.update(id, body);
        res.json({ coordenacao });
    };
    remove = async (req, res) => {
        const { id } = req.params;
        const existing = await this.coordenacaoRepo.findById(id);
        if (!existing)
            throw AppError_1.AppError.notFound('Coordenação não encontrada');
        await this.coordenacaoRepo.delete(id);
        res.status(204).send();
    };
}
exports.CoordenacaoController = CoordenacaoController;
