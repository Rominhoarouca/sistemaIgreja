"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.LoginUseCase = void 0;
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const AppError_1 = require("@shared/errors/AppError");
class LoginUseCase {
    userRepo;
    refreshTokenRepo;
    constructor(userRepo, refreshTokenRepo) {
        this.userRepo = userRepo;
        this.refreshTokenRepo = refreshTokenRepo;
    }
    async execute(input) {
        const normalizedEmail = input.email.toLowerCase().trim();
        const userWithPassword = await this.userRepo.findByEmail(normalizedEmail);
        if (!userWithPassword) {
            throw AppError_1.AppError.unauthorized('Credenciais inválidas');
        }
        const passwordMatch = await bcryptjs_1.default.compare(input.password, userWithPassword.password);
        if (!passwordMatch) {
            throw AppError_1.AppError.unauthorized('Credenciais inválidas');
        }
        const jwtSecret = process.env['JWT_SECRET'];
        const jwtRefreshSecret = process.env['JWT_REFRESH_SECRET'];
        const expiresIn = process.env['JWT_EXPIRES_IN'] ?? '15m';
        const refreshExpiresIn = process.env['JWT_REFRESH_EXPIRES_IN'] ?? '7d';
        if (!jwtSecret || !jwtRefreshSecret) {
            throw AppError_1.AppError.internal('Configuração JWT ausente');
        }
        const { password: _password, ...user } = userWithPassword;
        const accessToken = jsonwebtoken_1.default.sign({ sub: user.id, role: user.role }, jwtSecret, { expiresIn: expiresIn });
        const rawRefreshToken = jsonwebtoken_1.default.sign({ sub: user.id }, jwtRefreshSecret, { expiresIn: refreshExpiresIn });
        const expiresAt = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000);
        await this.refreshTokenRepo.create({
            token: rawRefreshToken,
            userId: user.id,
            expiresAt,
        });
        return { user, accessToken, refreshToken: rawRefreshToken };
    }
}
exports.LoginUseCase = LoginUseCase;
