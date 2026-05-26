"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.RegisterUserUseCase = void 0;
const bcryptjs_1 = __importDefault(require("bcryptjs"));
const crypto_1 = require("crypto");
const AppError_1 = require("@shared/errors/AppError");
class RegisterUserUseCase {
    userRepo;
    constructor(userRepo) {
        this.userRepo = userRepo;
    }
    async execute(input) {
        const existing = await this.userRepo.findByEmail(input.email);
        if (existing) {
            throw AppError_1.AppError.conflict('E-mail já cadastrado');
        }
        const hashed = await bcryptjs_1.default.hash(input.password, 12);
        const user = await this.userRepo.save({
            id: (0, crypto_1.randomUUID)(),
            name: input.name,
            email: input.email,
            password: hashed,
            role: input.role,
            photoKey: null,
            phone: null,
            address: null,
            birthDate: null,
        });
        return user;
    }
}
exports.RegisterUserUseCase = RegisterUserUseCase;
