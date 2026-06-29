"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
// Attempt to load .env if available, but don't crash if dotenv isn't installed
try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    require('dotenv').config();
}
catch (_err) {
    // dotenv not installed or failed to load — continue without throwing
}
const app_1 = require("./infrastructure/http/app");
const container_1 = require("./shared/container");
const logger_1 = require("@shared/logger/logger");
const http_1 = __importDefault(require("http"));
const PORT = Number(process.env['PORT'] ?? 3000);
async function bootstrap() {
    const container = (0, container_1.createContainer)();
    const app = (0, app_1.createApp)(container);
    // Only HTTP — TLS is handled by nginx/reverse-proxy in production
    const server = http_1.default.createServer(app).listen(PORT, '0.0.0.0', () => {
        logger_1.logger.info(`[API] Sistema Igreja rodando na porta ${PORT}`);
        logger_1.logger.info(`[API] Health: http://localhost:${PORT}/health`);
        // Also print to stdout to ensure parent watcher's terminal shows messages
        // (some watchers may not forward child stdio from logger transports)
        // eslint-disable-next-line no-console
        console.log(`[API] Sistema Igreja rodando na porta ${PORT}`);
        // eslint-disable-next-line no-console
        console.log(`[API] Health: http://localhost:${PORT}/health`);
    });
    // Graceful shutdown
    const shutdown = async (signal) => {
        logger_1.logger.info(`[API] Recebido ${signal}, encerrando...`);
        // eslint-disable-next-line no-console
        console.log(`[API] Recebido ${signal}, encerrando...`);
        server.close(async () => {
            await container.prisma.$disconnect();
            logger_1.logger.info('[API] Conexão com DB encerrada');
            // eslint-disable-next-line no-console
            console.log('[API] Conexão com DB encerrada');
            process.exit(0);
        });
    };
    process.on('SIGTERM', () => void shutdown('SIGTERM'));
    process.on('SIGINT', () => void shutdown('SIGINT'));
}
bootstrap().catch((err) => {
    logger_1.logger.error('[API] Falha ao iniciar:', err);
    process.exit(1);
});
