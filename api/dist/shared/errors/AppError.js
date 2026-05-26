"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.AppError = void 0;
class AppError extends Error {
    statusCode;
    code;
    constructor(message, statusCode = 400, code = 'BAD_REQUEST') {
        super(message);
        this.statusCode = statusCode;
        this.code = code;
        this.name = 'AppError';
        Object.setPrototypeOf(this, new.target.prototype);
    }
    static unauthorized(message = 'Não autorizado') {
        return new AppError(message, 401, 'UNAUTHORIZED');
    }
    static forbidden(message = 'Acesso negado') {
        return new AppError(message, 403, 'FORBIDDEN');
    }
    static notFound(message = 'Recurso não encontrado') {
        return new AppError(message, 404, 'NOT_FOUND');
    }
    static conflict(message) {
        return new AppError(message, 409, 'CONFLICT');
    }
    static internal(message = 'Erro interno') {
        return new AppError(message, 500, 'INTERNAL_ERROR');
    }
}
exports.AppError = AppError;
