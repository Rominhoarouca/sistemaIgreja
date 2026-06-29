"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.UserController = void 0;
const zod_1 = require("zod");
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const AppError_1 = require("@shared/errors/AppError");
const childSchema = zod_1.z.object({
    id: zod_1.z.string().uuid().optional(),
    name: zod_1.z.string().min(1),
    birthDate: zod_1.z.string().datetime({ offset: true }).nullable().optional(),
});
const updateProfileSchema = zod_1.z.object({
    name: zod_1.z.string().min(1).optional(),
    phone: zod_1.z.string().nullable().optional(),
    address: zod_1.z.string().nullable().optional(),
    birthDate: zod_1.z.string().datetime({ offset: true }).nullable().optional(),
    isMarried: zod_1.z.boolean().optional(),
    spouseName: zod_1.z.string().nullable().optional(),
    weddingDate: zod_1.z.string().datetime({ offset: true }).nullable().optional(),
    children: zod_1.z.array(childSchema).optional(),
});
class UserController {
    getProfileUseCase;
    updateProfileUseCase;
    userRepo;
    constructor(getProfileUseCase, updateProfileUseCase, userRepo) {
        this.getProfileUseCase = getProfileUseCase;
        this.updateProfileUseCase = updateProfileUseCase;
        this.userRepo = userRepo;
    }
    getProfile = async (req, res) => {
        const result = await this.getProfileUseCase.execute(req.userId);
        res.json({ user: result });
    };
    findLeaders = async (_req, res) => {
        const leaders = await this.userRepo.listLeaders();
        res.json({ leaders });
    };
    findSupervisors = async (_req, res) => {
        const supervisors = await this.userRepo.listSupervisors();
        res.json({ supervisors });
    };
    findCoordinadores = async (_req, res) => {
        const coordinadores = await this.userRepo.listCoordinadores();
        res.json({ supervisors: coordinadores });
    };
    getMyLeaders = async (req, res) => {
        const leaders = await this.userRepo.findLeadersBySupervisorId(req.userId);
        res.json({ leaders });
    };
    assignLeaderSupervisor = async (req, res) => {
        const { leaderId } = req.params;
        const { supervisorId } = zod_1.z.object({ supervisorId: zod_1.z.string().uuid().nullable() }).parse(req.body);
        await this.userRepo.assignSupervisor(leaderId, supervisorId);
        res.status(204).send();
    };
    promoteLeader = async (req, res) => {
        const { leaderId } = req.params;
        const { targetRole } = zod_1.z
            .object({ targetRole: zod_1.z.enum(['SUPERVISOR', 'COORDENADOR']) })
            .parse(req.body);
        const user = await this.userRepo.findById(leaderId);
        if (!user)
            throw AppError_1.AppError.notFound('Usuário não encontrado');
        if (user.role !== 'LIDER')
            throw new AppError_1.AppError('Apenas líderes podem ser promovidos', 422, 'INVALID_ROLE');
        await this.userRepo.promoteUser(leaderId, targetRole);
        res.status(204).send();
    };
    assignSupervisorCoordenacao = async (req, res) => {
        const { supervisorId } = req.params;
        const { coordenacaoId } = zod_1.z
            .object({ coordenacaoId: zod_1.z.string().uuid().nullable() })
            .parse(req.body);
        await this.userRepo.assignSupervisorToCoordenacao(supervisorId, coordenacaoId);
        res.status(204).send();
    };
    updateLeaderDescription = async (req, res) => {
        const { leaderId } = req.params;
        const { description } = zod_1.z.object({ description: zod_1.z.string().max(1000).nullable() }).parse(req.body);
        await this.userRepo.updateLeaderDescription(leaderId, description);
        res.status(204).send();
    };
    updateProfile = async (req, res) => {
        const rawBody = typeof req.body === 'string'
            ? JSON.parse(req.body)
            : (req.body ?? {});
        const toNullable = (value) => {
            if (value === '' || value === 'null' || value === 'undefined')
                return null;
            return value;
        };
        const normalizedBody = {
            ...rawBody,
            ...(rawBody.phone !== undefined ? { phone: toNullable(rawBody.phone) } : {}),
            ...(rawBody.address !== undefined ? { address: toNullable(rawBody.address) } : {}),
            ...(rawBody.birthDate !== undefined ? { birthDate: toNullable(rawBody.birthDate) } : {}),
            ...(rawBody.spouseName !== undefined ? { spouseName: toNullable(rawBody.spouseName) } : {}),
            ...(rawBody.weddingDate !== undefined ? { weddingDate: toNullable(rawBody.weddingDate) } : {}),
            ...(rawBody.isMarried !== undefined && typeof rawBody.isMarried === 'string'
                ? { isMarried: rawBody.isMarried === 'true' }
                : {}),
            ...(typeof rawBody.children === 'string'
                ? { children: JSON.parse(rawBody.children) }
                : {}),
        };
        const body = updateProfileSchema.parse(normalizedBody);
        const file = req.file;
        const { user, children } = await this.updateProfileUseCase.execute({
            userId: req.userId,
            ...(body.name !== undefined && { name: body.name }),
            ...(body.phone !== undefined && { phone: body.phone }),
            ...(body.address !== undefined && { address: body.address }),
            ...(body.birthDate !== undefined && { birthDate: body.birthDate }),
            ...(body.isMarried !== undefined && { isMarried: body.isMarried }),
            ...(body.spouseName !== undefined && { spouseName: body.spouseName }),
            ...(body.weddingDate !== undefined && { weddingDate: body.weddingDate }),
            ...(body.children !== undefined && {
                children: body.children.map((c) => ({
                    ...(c.id !== undefined && { id: c.id }),
                    name: c.name,
                    ...(c.birthDate !== undefined && { birthDate: c.birthDate }),
                })),
            }),
            ...(file && {
                fileBuffer: file.buffer,
                mimeType: file.mimetype,
                originalName: file.originalname,
            }),
        });
        res.json({ user, children });
    };
    createUser = async (req, res) => {
        const body = zod_1.z.object({
            name: zod_1.z.string().min(1),
            email: zod_1.z.string().email(),
            password: zod_1.z.string().min(6, 'Senha deve ter no mínimo 6 caracteres'),
            role: zod_1.z.enum(['SUPERVISOR', 'COORDENADOR']),
        }).parse(req.body);
        const existing = await this.userRepo.findByEmail(body.email);
        if (existing)
            throw new AppError_1.AppError('E-mail já cadastrado', 409, 'EMAIL_IN_USE');
        const hashedPassword = await bcryptjs_1.default.hash(body.password, 12);
        const user = await this.userRepo.createUser({
            name: body.name,
            email: body.email,
            password: hashedPassword,
            role: body.role,
        });
        res.status(201).json({ user });
    };
}
exports.UserController = UserController;
