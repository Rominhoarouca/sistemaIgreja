"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.UserController = void 0;
const zod_1 = require("zod");
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
}
exports.UserController = UserController;
