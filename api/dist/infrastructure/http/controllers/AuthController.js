"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AuthController = void 0;
const zod_1 = require("zod");
const AppError_1 = require("@shared/errors/AppError");
const loginSchema = zod_1.z.object({
    email: zod_1.z.string().email('E-mail inválido'),
    password: zod_1.z.string().min(6, 'Senha deve ter no mínimo 6 caracteres'),
});
const refreshSchema = zod_1.z.object({
    refreshToken: zod_1.z.string().min(1),
});
const registerSchema = zod_1.z.object({
    name: zod_1.z.string().min(2),
    email: zod_1.z.string().email('E-mail inválido'),
    password: zod_1.z.string().min(6, 'Senha deve ter no mínimo 6 caracteres'),
    role: zod_1.z.enum(['ADMIN', 'LIDER']),
});
class AuthController {
    loginUseCase;
    refreshTokenUseCase;
    registerUserUseCase;
    refreshTokenRepo;
    userRepo;
    constructor(loginUseCase, refreshTokenUseCase, registerUserUseCase, refreshTokenRepo, userRepo) {
        this.loginUseCase = loginUseCase;
        this.refreshTokenUseCase = refreshTokenUseCase;
        this.registerUserUseCase = registerUserUseCase;
        this.refreshTokenRepo = refreshTokenRepo;
        this.userRepo = userRepo;
    }
    login = async (req, res) => {
        const body = loginSchema.parse(req.body);
        const result = await this.loginUseCase.execute(body);
        res.json({
            user: result.user,
            accessToken: result.accessToken,
            refreshToken: result.refreshToken,
        });
    };
    refresh = async (req, res) => {
        const { refreshToken } = refreshSchema.parse(req.body);
        const result = await this.refreshTokenUseCase.execute(refreshToken);
        res.json({
            user: result.user,
            accessToken: result.accessToken,
            refreshToken: result.refreshToken,
        });
    };
    register = async (req, res) => {
        const data = registerSchema.parse(req.body);
        const user = await this.registerUserUseCase.execute(data);
        res.status(201).json({ user });
    };
    logout = async (req, res) => {
        const { refreshToken } = refreshSchema.parse(req.body);
        await this.refreshTokenRepo.deleteByToken(refreshToken);
        res.status(204).send();
    };
    me = async (req, res) => {
        const user = await this.userRepo.findById(req.userId);
        if (!user)
            throw AppError_1.AppError.notFound('Usuário não encontrado');
        res.json({ user });
    };
}
exports.AuthController = AuthController;
