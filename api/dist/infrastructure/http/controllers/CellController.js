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
    cellTypeId: zod_1.z.string().uuid().optional(),
    address: zod_1.z.string().min(3),
    bairroId: zod_1.z.string().uuid().optional(),
    dayOfWeek: zod_1.z.enum(['segunda', 'terca', 'quarta', 'quinta', 'sexta', 'sabado', 'domingo']),
    time: zod_1.z.string().regex(/^\d{2}:\d{2}$/, 'Horário deve ser HH:MM'),
    maxCapacity: zod_1.z.coerce.number().int().positive().optional(),
    latitude: zod_1.z.coerce.number().optional(),
    longitude: zod_1.z.coerce.number().optional(),
});
const updateCellSchema = zod_1.z.object({
    name: zod_1.z.string().min(2).optional(),
    leaderId: zod_1.z.string().uuid().optional(),
    cellTypeId: zod_1.z.string().uuid().nullable().optional(),
    address: zod_1.z.string().min(3).optional(),
    bairroId: zod_1.z.string().uuid().nullable().optional(),
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
    bairroId: zod_1.z.string().uuid().optional(),
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
        const createData = {
            name: data.name,
            leaderId: data.leaderId,
            cellTypeId: data.cellTypeId ?? null,
            address: data.address,
            bairroId: data.bairroId ?? null,
            dayOfWeek: data.dayOfWeek,
            time: data.time,
            ...(data.maxCapacity !== undefined && { maxCapacity: data.maxCapacity }),
            ...(data.latitude !== undefined && { latitude: data.latitude }),
            ...(data.longitude !== undefined && { longitude: data.longitude }),
        };
        const cell = await this.cellRepo.create(createData);
        res.status(201).json({ cell });
    };
    update = async (req, res) => {
        const { id } = req.params;
        const data = updateCellSchema.parse(req.body);
        const exists = await this.cellRepo.findById(id);
        if (!exists)
            throw AppError_1.AppError.notFound('Célula não encontrada');
        const updateData = {
            ...(data.name !== undefined && { name: data.name }),
            ...(data.leaderId !== undefined && { leaderId: data.leaderId }),
            ...(data.cellTypeId !== undefined && { cellTypeId: data.cellTypeId }),
            ...(data.address !== undefined && { address: data.address }),
            ...(data.bairroId !== undefined && { bairroId: data.bairroId }),
            ...(data.dayOfWeek !== undefined && { dayOfWeek: data.dayOfWeek }),
            ...(data.time !== undefined && { time: data.time }),
            ...(data.maxCapacity !== undefined && { maxCapacity: data.maxCapacity }),
            ...(data.latitude !== undefined && { latitude: data.latitude }),
            ...(data.longitude !== undefined && { longitude: data.longitude }),
        };
        const cell = await this.cellRepo.update(id, updateData);
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
            name: data.name,
            phone: data.phone,
            ...(data.email !== undefined ? { email: data.email } : {}),
            ...(data.address !== undefined ? { address: data.address } : {}),
            ...(data.bairroId !== undefined ? { bairroId: data.bairroId } : {}),
            ...(data.leaderId !== undefined ? { leaderId: data.leaderId } : {}),
        });
        res.status(201).json({ member });
    };
    findByLeader = async (req, res) => {
        const cells = await this.cellRepo.findByLeaderId(req.userId);
        res.json({ cells });
    };
}
exports.CellController = CellController;
