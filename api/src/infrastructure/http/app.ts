import 'express-async-errors';
import express, { type Application } from 'express';
import cors from 'cors';
import helmet from 'helmet';
import swaggerUi from 'swagger-ui-express';

import { authRoutes } from './routes/auth.routes';
import { visitorRoutes } from './routes/visitor.routes';
import { cellRoutes } from './routes/cell.routes';
import { attendanceRoutes } from './routes/attendance.routes';
import { spiritualHistoryRoutes } from './routes/spiritual-history.routes';
import { dashboardRoutes } from './routes/dashboard.routes';
import { materialRoutes } from './routes/material.routes';
import { userRoutes } from './routes/user.routes';
import { errorMiddleware } from './middlewares/error.middleware';
import { requestLoggerMiddleware } from './middlewares/request-logger.middleware';
import { openApiSpec } from '@shared/swagger/openapi.spec';
import type { Container } from '@shared/container';

export function createApp(container: Container): Application {
  const app = express();

  // Security — relax CSP only for Swagger UI
  app.use(
    helmet({
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          scriptSrc: ["'self'", "'unsafe-inline'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          imgSrc: ["'self'", 'data:', 'https:'],
        },
      },
    }),
  );
  app.use(
    cors({
      origin: process.env['ALLOWED_ORIGINS']?.split(',') ?? '*',
      methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
      allowedHeaders: ['Content-Type', 'Authorization'],
    }),
  );

  // Body parsing
  app.use(express.json({ limit: '10mb' }));
  app.use(express.urlencoded({ extended: true }));

  // Request logging (active when in development or when LOG_LEVEL requests it)
  const verboseLevels = ['http', 'info', 'debug', 'verbose', 'silly'];
  const logLevel = process.env['LOG_LEVEL']?.toLowerCase();
  if (process.env['NODE_ENV'] === 'development' || (logLevel != null && verboseLevels.includes(logLevel))) {
    app.use(requestLoggerMiddleware);
  }

  // Swagger UI — available at /docs
  app.use('/docs', swaggerUi.serve, swaggerUi.setup(openApiSpec, {
    customSiteTitle: 'Sistema Igreja API Docs',
    swaggerOptions: {
      persistAuthorization: true,
      displayRequestDuration: true,
      filter: true,
    },
  }));

  // OpenAPI spec as JSON — useful for code generators
  app.get('/docs.json', (_req, res) => {
    res.json(openApiSpec);
  });

  // Health check
  app.get('/health', (_req, res) => {
    res.json({ status: 'ok', timestamp: new Date().toISOString() });
  });

  // Routes
  const v1 = '/v1';
  app.use(`${v1}/auth`, authRoutes(container.authController));
  app.use(`${v1}/visitors`, visitorRoutes(container.visitorController));
  app.use(`${v1}/cells`, cellRoutes(container.cellController));
  app.use(`${v1}/attendance`, attendanceRoutes(container.attendanceController));
  app.use(`${v1}/spiritual-history`, spiritualHistoryRoutes(container.spiritualHistoryController));
  app.use(`${v1}/dashboard`, dashboardRoutes(container.dashboardController));
  app.use(`${v1}/materials`, materialRoutes(container.materialController));
  app.use(`${v1}/users`, userRoutes(container.userController));

  // Error handler (must be last)
  app.use(errorMiddleware);

  return app;
}
