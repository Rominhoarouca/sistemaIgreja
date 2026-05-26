"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.errorMiddleware = errorMiddleware;
const AppError_1 = require("@shared/errors/AppError");
const zod_1 = require("zod");
function errorMiddleware(err, _req, res, _next) {
    if (err instanceof AppError_1.AppError) {
        res.status(err.statusCode).json({ error: { code: err.code, message: err.message } });
        return;
    }
    if (err instanceof zod_1.ZodError) {
        res.status(422).json({
            error: {
                code: 'VALIDATION_ERROR',
                message: 'Dados inválidos',
                details: err.flatten().fieldErrors,
            },
        });
        return;
    }
    console.error('[Unhandled Error]', err);
    res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: 'Erro interno do servidor' } });
}
