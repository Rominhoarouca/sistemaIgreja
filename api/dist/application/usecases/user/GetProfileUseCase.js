"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.GetProfileUseCase = void 0;
const AppError_1 = require("@shared/errors/AppError");
class GetProfileUseCase {
    userRepo;
    minioService;
    constructor(userRepo, minioService) {
        this.userRepo = userRepo;
        this.minioService = minioService;
    }
    async execute(userId) {
        const user = await this.userRepo.getProfile(userId);
        if (!user)
            throw AppError_1.AppError.notFound('Usuário não encontrado');
        let photoUrl = null;
        if (user.photoKey) {
            photoUrl = await this.minioService.presignedDownloadUrl(user.photoKey);
        }
        return { ...user, photoUrl };
    }
}
exports.GetProfileUseCase = GetProfileUseCase;
