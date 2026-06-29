"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.authMiddleware = authMiddleware;
exports.requireAdmin = requireAdmin;
exports.requireSupervisor = requireSupervisor;
exports.requireSupervisorOrAdmin = requireSupervisorOrAdmin;
const jsonwebtoken_1 = __importDefault(require("jsonwebtoken"));
const AppError_1 = require("@shared/errors/AppError");
function authMiddleware(req, _res, next) {
    const authHeader = req.headers['authorization'];
    if (!authHeader?.startsWith('Bearer ')) {
        throw AppError_1.AppError.unauthorized('Token não fornecido');
    }
    const token = authHeader.split(' ')[1];
    if (!token)
        throw AppError_1.AppError.unauthorized('Token inválido');
    const secret = process.env['JWT_SECRET'];
    if (!secret)
        throw AppError_1.AppError.internal('Configuração JWT ausente');
    try {
        const payload = jsonwebtoken_1.default.verify(token, secret);
        req.userId = payload.sub;
        req.userRole = payload.role;
        next();
    }
    catch {
        throw AppError_1.AppError.unauthorized('Token inválido ou expirado');
    }
}
function requireAdmin(req, _res, next) {
    if (req.userRole !== 'ADMIN') {
        throw AppError_1.AppError.forbidden('Acesso restrito a administradores');
    }
    next();
}
function requireSupervisor(req, _res, next) {
    if (req.userRole !== 'SUPERVISOR') {
        throw AppError_1.AppError.forbidden('Acesso restrito a supervisores');
    }
    next();
}
function requireSupervisorOrAdmin(req, _res, next) {
    if (req.userRole !== 'ADMIN' && req.userRole !== 'SUPERVISOR') {
        throw AppError_1.AppError.forbidden('Acesso restrito a supervisores e administradores');
    }
    next();
}
