import type { Request, Response, NextFunction } from 'express';
import { logger } from '@shared/logger/logger';

const isVerbose = () =>
  ['verbose', 'debug', 'silly'].includes(
    (process.env['LOG_LEVEL'] ?? '').toLowerCase(),
  );

/**
 * Logs every HTTP request at the `http` level.
 * When LOG_LEVEL=verbose also logs request body, response body and duration.
 */
export function requestLoggerMiddleware(
  req: Request,
  res: Response,
  next: NextFunction,
): void {
  const start = Date.now();

  // Capture request body snapshot before it can be consumed
  const reqBody: unknown = req.body;

  // Intercept res.json() to capture the response body
  let resBody: unknown;
  const originalJson = res.json.bind(res) as (body?: unknown) => Response;
  res.json = (body?: unknown): Response => {
    resBody = body;
    return originalJson(body);
  };

  res.on('finish', () => {
    const ms = Date.now() - start;
    const { method, originalUrl } = req;
    const { statusCode } = res;
    const isError = statusCode >= 400;

    if (isVerbose()) {
      const meta: Record<string, unknown> = {
        status: statusCode,
        ms,
        ip: req.ip ?? req.socket.remoteAddress,
        userAgent: req.headers['user-agent'],
      };

      if (reqBody && Object.keys(reqBody as object).length > 0) {
        // Mask sensitive fields
        const sanitized = { ...(reqBody as Record<string, unknown>) };
        for (const key of ['password', 'senha', 'token', 'refreshToken', 'secret']) {
          if (key in sanitized) sanitized[key] = '***';
        }
        meta['reqBody'] = sanitized;
      }

      if (resBody !== undefined) {
        meta['resBody'] = resBody;
      }

      const logFn = isError ? logger.warn.bind(logger) : logger.verbose.bind(logger);
      logFn(`${method} ${originalUrl}`, meta);
    } else {
      logger.http(`${method} ${originalUrl}`, {
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
