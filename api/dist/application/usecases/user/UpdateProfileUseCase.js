"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.UpdateProfileUseCase = void 0;
const AppError_1 = require("@shared/errors/AppError");
const path_1 = __importDefault(require("path"));
class UpdateProfileUseCase {
    userRepo;
    minioService;
    constructor(userRepo, minioService) {
        this.userRepo = userRepo;
        this.minioService = minioService;
    }
    async execute(input) {
        const existing = await this.userRepo.findById(input.userId);
        if (!existing)
            throw AppError_1.AppError.notFound('Usuário não encontrado');
        let photoKey;
        if (input.fileBuffer && input.mimeType && input.originalName) {
            const ext = path_1.default.extname(input.originalName).toLowerCase() || '.jpg';
            const objectName = `users/${input.userId}/photo${ext}`;
            await this.minioService.uploadFile({
                objectName,
                buffer: input.fileBuffer,
                mimeType: input.mimeType,
                size: input.fileBuffer.length,
            });
            photoKey = objectName;
        }
        const user = await this.userRepo.updateProfile(input.userId, {
            ...(input.name !== undefined && { name: input.name }),
            ...(input.phone !== undefined && { phone: input.phone }),
            ...(input.address !== undefined && { address: input.address }),
            ...(input.birthDate !== undefined && {
                birthDate: input.birthDate ? new Date(input.birthDate) : null,
            }),
            ...(photoKey !== undefined && { photoKey }),
        });
        const childrenInput = (input.children ?? []).map((c) => ({
            ...(c.id !== undefined && { id: c.id }),
            name: c.name,
            ...(c.birthDate !== undefined && { birthDate: c.birthDate ? new Date(c.birthDate) : null }),
        }));
        const children = await this.userRepo.upsertChildren(input.userId, childrenInput);
        return { user, children };
    }
}
exports.UpdateProfileUseCase = UpdateProfileUseCase;
