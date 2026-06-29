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
    bairroId: zod_1.z.string().uuid().optional(),
    originChurch: zod_1.z.string().optional(),
    leaderId: zod_1.z.string().uuid().optional(),
    cellId: zod_1.z.string().uuid().optional(),
    referredById: zod_1.z.string().uuid().optional(),
});
const selfRegisterSchema = zod_1.z.object({
    name: zod_1.z.string().min(2),
    phone: zod_1.z.string().min(8),
    address: zod_1.z.string().min(3),
    numero: zod_1.z.string().min(1),
    complemento: zod_1.z.string().optional(),
    bairroId: zod_1.z.string().uuid(),
    birthDate: zod_1.z.string().datetime({ local: true, offset: true }).optional().or(zod_1.z.string().regex(/^\d{4}-\d{2}-\d{2}$/).optional()),
    maritalStatus: zod_1.z.string().optional(),
    isBaptized: zod_1.z.boolean().default(false),
    knownPersonName: zod_1.z.string().optional(),
    interests: zod_1.z.array(zod_1.z.string()).default([]),
    cellId: zod_1.z.string().uuid().optional(),
    customCellName: zod_1.z.string().optional(),
});
const statusSchema = zod_1.z.object({
    status: zod_1.z.enum(['novo', 'em_acompanhamento', 'integrado', 'inativo']),
    leaderId: zod_1.z.string().uuid().optional(),
    cellId: zod_1.z.string().uuid().optional(),
});
const assignCellSchema = zod_1.z.object({
    cellId: zod_1.z.string().uuid().nullable(),
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
    selfRegister = async (req, res) => {
        const data = selfRegisterSchema.parse(req.body);
        const birthDate = data.birthDate ? new Date(data.birthDate) : undefined;
        // Store custom cell name in originChurch when not linked to a known cell
        const originChurch = !data.cellId && data.customCellName ? data.customCellName : undefined;
        const visitor = await this.registerUseCase.execute({
            name: data.name,
            phone: data.phone,
            address: data.address,
            numero: data.numero,
            complemento: data.complemento,
            bairroId: data.bairroId,
            birthDate,
            maritalStatus: data.maritalStatus,
            isBaptized: data.isBaptized,
            knownPersonName: data.knownPersonName,
            interests: data.interests,
            cellId: data.cellId,
            originChurch,
        });
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
    assignCell = async (req, res) => {
        const { id } = req.params;
        const { cellId } = assignCellSchema.parse(req.body);
        const visitor = await this.visitorRepo.findById(id);
        if (!visitor)
            throw AppError_1.AppError.notFound('Visitante não encontrado');
        const updated = await this.visitorRepo.updateStatus(id, {
            status: visitor.status,
            cellId: cellId ?? undefined,
        });
        res.json({ visitor: updated });
    };
}
exports.VisitorController = VisitorController;
