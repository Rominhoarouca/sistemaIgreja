"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.CellController = void 0;
const zod_1 = require("zod");
const AppError_1 = require("@shared/errors/AppError");
const nearbySchema = zod_1.z.object({
    lat: zod_1.z.coerce.number().min(-90).max(90),
    lng: zod_1.z.coerce.number().min(-180).max(180),
    radius: zod_1.z.coerce.number().positive().max(100).default(10),
});
const createCellSchema = zod_1.z.object({
    name: zod_1.z.string().min(2),
    leaderId: zod_1.z.string().uuid(),
    address: zod_1.z.string().min(3),
    neighborhood: zod_1.z.string().min(2),
    city: zod_1.z.string().min(2),
    dayOfWeek: zod_1.z.enum(['segunda', 'terca', 'quarta', 'quinta', 'sexta', 'sabado', 'domingo']),
    time: zod_1.z.string().regex(/^\d{2}:\d{2}$/, 'Horário deve ser HH:MM'),
    maxCapacity: zod_1.z.coerce.number().int().positive().optional(),
    latitude: zod_1.z.coerce.number().optional(),
    longitude: zod_1.z.coerce.number().optional(),
});
const updateCellSchema = zod_1.z.object({
    name: zod_1.z.string().min(2).optional(),
    leaderId: zod_1.z.string().uuid().optional(),
    address: zod_1.z.string().min(3).optional(),
    neighborhood: zod_1.z.string().min(2).optional(),
    city: zod_1.z.string().min(2).optional(),
    dayOfWeek: zod_1.z.enum(['segunda', 'terca', 'quarta', 'quinta', 'sexta', 'sabado', 'domingo']).optional(),
    time: zod_1.z.string().regex(/^\d{2}:\d{2}$/, 'Horário deve ser HH:MM').optional(),
    maxCapacity: zod_1.z.coerce.number().int().nonnegative().optional(),
    latitude: zod_1.z.coerce.number().nullable().optional(),
    longitude: zod_1.z.coerce.number().nullable().optional(),
});
const createMemberSchema = zod_1.z.object({
    name: zod_1.z.string().min(2),
    phone: zod_1.z.string().min(8),
    email: zod_1.z.string().email().optional(),
    address: zod_1.z.string().optional(),
    neighborhood: zod_1.z.string().optional(),
    city: zod_1.z.string().optional(),
    leaderId: zod_1.z.string().uuid().optional(),
});
class CellController {
    getNearbyCellsUseCase;
    cellRepo;
    cellMemberRepo;
    constructor(getNearbyCellsUseCase, cellRepo, cellMemberRepo) {
        this.getNearbyCellsUseCase = getNearbyCellsUseCase;
        this.cellRepo = cellRepo;
        this.cellMemberRepo = cellMemberRepo;
    }
    findNearby = async (req, res) => {
        const { lat, lng, radius } = nearbySchema.parse(req.query);
        const cells = await this.getNearbyCellsUseCase.execute({
            latitude: lat,
            longitude: lng,
            radiusKm: radius,
        });
        res.json({ cells });
    };
    findAll = async (_req, res) => {
        const cells = await this.cellRepo.findAll();
        res.json({ cells });
    };
    findById = async (req, res) => {
        const { id } = req.params;
        const cell = await this.cellRepo.findById(id);
        if (!cell)
            throw AppError_1.AppError.notFound('Célula não encontrada');
        res.json({ cell });
    };
    create = async (req, res) => {
        const data = createCellSchema.parse(req.body);
        const cell = await this.cellRepo.create(data);
        res.status(201).json({ cell });
    };
    update = async (req, res) => {
        const { id } = req.params;
        const data = updateCellSchema.parse(req.body);
        const exists = await this.cellRepo.findById(id);
        if (!exists)
            throw AppError_1.AppError.notFound('Célula não encontrada');
        const cell = await this.cellRepo.update(id, data);
        res.json({ cell });
    };
    delete = async (req, res) => {
        const { id } = req.params;
        const exists = await this.cellRepo.findById(id);
        if (!exists)
            throw AppError_1.AppError.notFound('Célula não encontrada');
        await this.cellRepo.delete(id);
        res.status(204).send();
    };
    listMembers = async (req, res) => {
        const { id } = req.params;
        const cell = await this.cellRepo.findById(id);
        if (!cell)
            throw AppError_1.AppError.notFound('Célula não encontrada');
        const members = await this.cellMemberRepo.findByCellId(id);
        res.json({ members });
    };
    addMember = async (req, res) => {
        const { id } = req.params;
        const cell = await this.cellRepo.findById(id);
        if (!cell)
            throw AppError_1.AppError.notFound('Célula não encontrada');
        const data = createMemberSchema.parse(req.body);
        const member = await this.cellMemberRepo.create({
            cellId: id,
            ...data,
        });
        res.status(201).json({ member });
    };
    findByLeader = async (req, res) => {
        const cell = await this.cellRepo.findByLeaderId(req.userId);
        if (!cell)
            throw AppError_1.AppError.notFound('Nenhuma célula associada a este líder');
        res.json({ cell });
    };
}
exports.CellController = CellController;
