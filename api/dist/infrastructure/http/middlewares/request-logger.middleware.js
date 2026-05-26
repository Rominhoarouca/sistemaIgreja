"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.requestLoggerMiddleware = requestLoggerMiddleware;
const logger_1 = require("@shared/logger/logger");
/**
 * Logs every HTTP request at the `http` level.
 * Active only when NODE_ENV=development (LOG_LEVEL must be http or lower).
 */
function requestLoggerMiddleware(req, res, next) {
    const start = Date.now();
    res.on('finish', () => {
        const ms = Date.now() - start;
        const { method, originalUrl } = req;
        const { statusCode } = res;
        logger_1.logger.http(`${method} ${originalUrl}`, {
            status: statusCode,
            ms,
            ip: req.ip ?? req.socket.remoteAddress,
            userAgent: req.headers['user-agent'],
        });
        // Also output to stdout to ensure visibility under different watchers
        // eslint-disable-next-line no-console
        console.log(`${method} ${originalUrl} ${statusCode} ${ms}ms`);
    });
    next();
}
