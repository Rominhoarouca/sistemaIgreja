"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.VisitorController = void 0;
const zod_1 = require("zod");
const AppError_1 = require("@shared/errors/AppError");
const createSchema = zod_1.z.object({
    name: zod_1.z.string().min(2),
    phone: zod_1.z.string().min(8),
    email: zod_1.z.string().email().optional(),
    address: zod_1.z.string().optional(),
    neighborhood: zod_1.z.string().optional(),
    city: zod_1.z.string().optional(),
    originChurch: zod_1.z.string().optional(),
    leaderId: zod_1.z.string().uuid().optional(),
    cellId: zod_1.z.string().uuid().optional(),
    referredById: zod_1.z.string().uuid().optional(),
});
const statusSchema = zod_1.z.object({
    status: zod_1.z.enum(['novo', 'em_acompanhamento', 'integrado', 'inativo']),
    leaderId: zod_1.z.string().uuid().optional(),
    cellId: zod_1.z.string().uuid().optional(),
});
const querySchema = zod_1.z.object({
    leaderId: zod_1.z.string().uuid().optional(),
    cellId: zod_1.z.string().uuid().optional(),
    status: zod_1.z.enum(['novo', 'em_acompanhamento', 'integrado', 'inativo']).optional(),
    search: zod_1.z.string().optional(),
    page: zod_1.z.coerce.number().int().positive().default(1),
    pageSize: zod_1.z.coerce.number().int().positive().max(100).default(20),
});
const convertSchema = zod_1.z.object({
    cellId: zod_1.z.string().uuid().optional(),
});
class VisitorController {
    registerUseCase;
    getVisitorsUseCase;
    updateStatusUseCase;
    visitorRepo;
    cellMemberRepo;
    constructor(registerUseCase, getVisitorsUseCase, updateStatusUseCase, visitorRepo, cellMemberRepo) {
        this.registerUseCase = registerUseCase;
        this.getVisitorsUseCase = getVisitorsUseCase;
        this.updateStatusUseCase = updateStatusUseCase;
        this.visitorRepo = visitorRepo;
        this.cellMemberRepo = cellMemberRepo;
    }
    create = async (req, res) => {
        const data = createSchema.parse(req.body);
        const visitor = await this.registerUseCase.execute(data);
        res.status(201).json({ visitor });
    };
    findAll = async (req, res) => {
        const filters = querySchema.parse(req.query);
        const result = await this.getVisitorsUseCase.execute(filters);
        res.json(result);
    };
    findById = async (req, res) => {
        const { id } = req.params;
        const visitor = await this.visitorRepo.findById(id);
        if (!visitor)
            throw AppError_1.AppError.notFound('Visitante não encontrado');
        res.json({ visitor });
    };
    updateStatus = async (req, res) => {
        const { id } = req.params;
        const data = statusSchema.parse(req.body);
        const visitor = await this.updateStatusUseCase.execute(id, data);
        res.json({ visitor });
    };
    convertToMember = async (req, res) => {
        const { id } = req.params;
        const { cellId } = convertSchema.parse(req.body ?? {});
        const member = await this.cellMemberRepo.convertVisitorToMember(id, cellId);
        const visitor = await this.visitorRepo.findById(id);
        if (!visitor)
            throw AppError_1.AppError.notFound('Visitante não encontrado');
        res.json({ member, visitor });
    };
}
exports.VisitorController = VisitorController;
