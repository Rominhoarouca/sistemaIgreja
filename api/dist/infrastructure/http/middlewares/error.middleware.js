"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.errorMiddleware = errorMiddleware;
const client_1 = require("@prisma/client");
const AppError_1 = require("@shared/errors/AppError");
const zod_1 = require("zod");
const logger_1 = require("@shared/logger/logger");
const isVerbose = () => ['verbose', 'debug', 'silly'].includes((process.env['LOG_LEVEL'] ?? '').toLowerCase());
function errorMiddleware(err, req, res, _next) {
    // Always log errors; include stacktrace on verbose
    if (isVerbose()) {
        logger_1.logger.error(`[Error] ${req.method} ${req.originalUrl}`, {
            error: err instanceof Error ? err.message : String(err),
            stack: err instanceof Error ? err.stack : undefined,
            reqBody: req.body,
        });
    }
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
    if (err instanceof client_1.Prisma.PrismaClientKnownRequestError) {
        if (err.code === 'P2002') {
            const target = Array.isArray(err.meta?.target)
                ? err.meta.target
                : [];
            const isLeaderCellConflict = target.includes('leader_id') || target.includes('leaderId');
            res.status(409).json({
                error: {
                    code: 'CONFLICT',
                    message: isLeaderCellConflict
                        ? 'Este líder já possui uma célula cadastrada'
                        : 'Conflito de unicidade nos dados enviados',
                },
            });
            return;
        }
    }
    if (!isVerbose()) {
        console.error('[Unhandled Error]', err);
    }
    res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: 'Erro interno do servidor' } });
}
