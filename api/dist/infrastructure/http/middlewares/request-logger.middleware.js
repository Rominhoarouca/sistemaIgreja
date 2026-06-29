"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.requestLoggerMiddleware = requestLoggerMiddleware;
const logger_1 = require("@shared/logger/logger");
const isVerbose = () => ['verbose', 'debug', 'silly'].includes((process.env['LOG_LEVEL'] ?? '').toLowerCase());
/**
 * Logs every HTTP request at the `http` level.
 * When LOG_LEVEL=verbose also logs request body, response body and duration.
 */
function requestLoggerMiddleware(req, res, next) {
    const start = Date.now();
    // Capture request body snapshot before it can be consumed
    const reqBody = req.body;
    // Intercept res.json() to capture the response body
    let resBody;
    const originalJson = res.json.bind(res);
    res.json = (body) => {
        resBody = body;
        return originalJson(body);
    };
    res.on('finish', () => {
        const ms = Date.now() - start;
        const { method, originalUrl } = req;
        const { statusCode } = res;
        const isError = statusCode >= 400;
        if (isVerbose()) {
            const meta = {
                status: statusCode,
                ms,
                ip: req.ip ?? req.socket.remoteAddress,
                userAgent: req.headers['user-agent'],
            };
            if (reqBody && Object.keys(reqBody).length > 0) {
                // Mask sensitive fields
                const sanitized = { ...reqBody };
                for (const key of ['password', 'senha', 'token', 'refreshToken', 'secret']) {
                    if (key in sanitized)
                        sanitized[key] = '***';
                }
                meta['reqBody'] = sanitized;
            }
            if (resBody !== undefined) {
                meta['resBody'] = resBody;
            }
            const logFn = isError ? logger_1.logger.warn.bind(logger_1.logger) : logger_1.logger.verbose.bind(logger_1.logger);
            logFn(`${method} ${originalUrl}`, meta);
        }
        else {
            logger_1.logger.http(`${method} ${originalUrl}`, {
                status: statusCode,
                ms,
                ip: req.ip ?? req.socket.remoteAddress,
                userAgent: req.headers['user-agent'],
            });
        }
        // eslint-disable-next-line no-console
        console.log(`${method} ${originalUrl} ${statusCode} ${ms}ms`);
    });
    next();
}
