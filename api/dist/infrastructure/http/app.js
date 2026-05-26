"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.createApp = createApp;
require("express-async-errors");
const express_1 = __importDefault(require("express"));
const cors_1 = __importDefault(require("cors"));
const helmet_1 = __importDefault(require("helmet"));
const swagger_ui_express_1 = __importDefault(require("swagger-ui-express"));
const auth_routes_1 = require("./routes/auth.routes");
const visitor_routes_1 = require("./routes/visitor.routes");
const cell_routes_1 = require("./routes/cell.routes");
const attendance_routes_1 = require("./routes/attendance.routes");
const spiritual_history_routes_1 = require("./routes/spiritual-history.routes");
const dashboard_routes_1 = require("./routes/dashboard.routes");
const material_routes_1 = require("./routes/material.routes");
const user_routes_1 = require("./routes/user.routes");
const error_middleware_1 = require("./middlewares/error.middleware");
const request_logger_middleware_1 = require("./middlewares/request-logger.middleware");
const openapi_spec_1 = require("@shared/swagger/openapi.spec");
function createApp(container) {
    const app = (0, express_1.default)();
    // Security — relax CSP only for Swagger UI
    app.use((0, helmet_1.default)({
        contentSecurityPolicy: {
            directives: {
                defaultSrc: ["'self'"],
                scriptSrc: ["'self'", "'unsafe-inline'"],
                styleSrc: ["'self'", "'unsafe-inline'"],
                imgSrc: ["'self'", 'data:', 'https:'],
            },
        },
    }));
    app.use((0, cors_1.default)({
        origin: process.env['ALLOWED_ORIGINS']?.split(',') ?? '*',
        methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
        allowedHeaders: ['Content-Type', 'Authorization'],
    }));
    // Body parsing
    app.use(express_1.default.json({ limit: '10mb' }));
    app.use(express_1.default.urlencoded({ extended: true }));
    // Request logging (active when in development or when LOG_LEVEL requests it)
    const verboseLevels = ['http', 'info', 'debug', 'verbose', 'silly'];
    const logLevel = process.env['LOG_LEVEL']?.toLowerCase();
    if (process.env['NODE_ENV'] === 'development' || (logLevel != null && verboseLevels.includes(logLevel))) {
        app.use(request_logger_middleware_1.requestLoggerMiddleware);
    }
    // Swagger UI — available at /docs
    app.use('/docs', swagger_ui_express_1.default.serve, swagger_ui_express_1.default.setup(openapi_spec_1.openApiSpec, {
        customSiteTitle: 'Sistema Igreja API Docs',
        swaggerOptions: {
            persistAuthorization: true,
            displayRequestDuration: true,
            filter: true,
        },
    }));
    // OpenAPI spec as JSON — useful for code generators
    app.get('/docs.json', (_req, res) => {
        res.json(openapi_spec_1.openApiSpec);
    });
    // Health check
    app.get('/health', (_req, res) => {
        res.json({ status: 'ok', timestamp: new Date().toISOString() });
    });
    // Routes
    const v1 = '/v1';
    app.use(`${v1}/auth`, (0, auth_routes_1.authRoutes)(container.authController));
    app.use(`${v1}/visitors`, (0, visitor_routes_1.visitorRoutes)(container.visitorController));
    app.use(`${v1}/cells`, (0, cell_routes_1.cellRoutes)(container.cellController));
    app.use(`${v1}/attendance`, (0, attendance_routes_1.attendanceRoutes)(container.attendanceController));
    app.use(`${v1}/spiritual-history`, (0, spiritual_history_routes_1.spiritualHistoryRoutes)(container.spiritualHistoryController));
    app.use(`${v1}/dashboard`, (0, dashboard_routes_1.dashboardRoutes)(container.dashboardController));
    app.use(`${v1}/materials`, (0, material_routes_1.materialRoutes)(container.materialController));
    app.use(`${v1}/users`, (0, user_routes_1.userRoutes)(container.userController));
    // Error handler (must be last)
    app.use(error_middleware_1.errorMiddleware);
    return app;
}
