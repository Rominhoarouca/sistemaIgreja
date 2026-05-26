"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.RefreshTokenUseCase = void 0;
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const AppError_1 = require("@shared/errors/AppError");
class RefreshTokenUseCase {
    userRepo;
    refreshTokenRepo;
    constructor(userRepo, refreshTokenRepo) {
        this.userRepo = userRepo;
        this.refreshTokenRepo = refreshTokenRepo;
    }
    async execute(token) {
        const jwtRefreshSecret = process.env['JWT_REFRESH_SECRET'];
        const jwtSecret = process.env['JWT_SECRET'];
        const expiresIn = process.env['JWT_EXPIRES_IN'] ?? '15m';
        const refreshExpiresIn = process.env['JWT_REFRESH_EXPIRES_IN'] ?? '7d';
        if (!jwtSecret || !jwtRefreshSecret) {
            throw AppError_1.AppError.internal('Configuração JWT ausente');
        }
        const stored = await this.refreshTokenRepo.findByToken(token);
        if (!stored || stored.expiresAt < new Date()) {
            throw AppError_1.AppError.unauthorized('Refresh token inválido ou expirado');
        }
        try {
            jsonwebtoken_1.default.verify(token, jwtRefreshSecret);
        }
        catch {
            throw AppError_1.AppError.unauthorized('Refresh token inválido');
        }
        const user = await this.userRepo.findById(stored.userId);
        if (!user)
            throw AppError_1.AppError.unauthorized('Usuário não encontrado');
        await this.refreshTokenRepo.deleteByToken(token);
        const accessToken = jsonwebtoken_1.default.sign({ sub: user.id, role: user.role }, jwtSecret, { expiresIn });
        const newRefreshToken = jsonwebtoken_1.default.sign({ sub: user.id }, jwtRefreshSecret, { expiresIn: refreshExpiresIn });
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        await this.refreshTokenRepo.create({ token: newRefreshToken, userId: user.id, expiresAt });
        return { user, accessToken, refreshToken: newRefreshToken };
    }
}
exports.RefreshTokenUseCase = RefreshTokenUseCase;
