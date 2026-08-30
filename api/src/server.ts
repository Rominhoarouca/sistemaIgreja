// Attempt to load .env if available, but don't crash if dotenv isn't installed
try {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  require('dotenv').config();
} catch (_err) {
  // dotenv not installed or failed to load — continue without throwing
}
import { createApp } from './infrastructure/http/app';
import { createContainer } from './shared/container';
import { logger } from '@shared/logger/logger';
import http from 'http';

const PORT = Number(process.env['PORT'] ?? 3000);

async function bootstrap(): Promise<void> {
  const container = createContainer();
  const app = createApp(container);

  // Valida o storage no boot: sem isso, credencial errada só aparecia como
  // 500 na primeira tentativa de upload do usuário.
  container.minioService.healthCheck().catch((err: unknown) => {
    logger.error(
      '[API] Armazenamento de arquivos indisponível — uploads vão falhar',
      err as Error,
    );
  });

  // Only HTTP — TLS is handled by nginx/reverse-proxy in production
  const server = http.createServer(app).listen(PORT, '0.0.0.0', () => {
    logger.info(`[API] Sistema Igreja rodando na porta ${PORT}`);
    logger.info(`[API] Health: http://localhost:${PORT}/health`);
    // Also print to stdout to ensure parent watcher's terminal shows messages
    // (some watchers may not forward child stdio from logger transports)
    // eslint-disable-next-line no-console
    console.log(`[API] Sistema Igreja rodando na porta ${PORT}`);
    // eslint-disable-next-line no-console
    console.log(`[API] Health: http://localhost:${PORT}/health`);
  });

  // Graceful shutdown
  const shutdown = async (signal: string): Promise<void> => {
    logger.info(`[API] Recebido ${signal}, encerrando...`);
    // eslint-disable-next-line no-console
    console.log(`[API] Recebido ${signal}, encerrando...`);
    server.close(async () => {
      await container.prisma.$disconnect();
      logger.info('[API] Conexão com DB encerrada');
      // eslint-disable-next-line no-console
      console.log('[API] Conexão com DB encerrada');
      process.exit(0);
    });
  };

  process.on('SIGTERM', () => void shutdown('SIGTERM'));
  process.on('SIGINT', () => void shutdown('SIGINT'));
}

bootstrap().catch((err) => {
  logger.error('[API] Falha ao iniciar:', err as Error);
  process.exit(1);
});
